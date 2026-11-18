package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"syscall"
	"time"
)

type config struct {
	Port                string
	DatabaseURL         string
	RedisAddr           string
	DBConnectRetries    int
	DBConnectRetryDelay time.Duration
	EnableDebug         bool
	CanarySecret        string
	InstanceID          string
	AppVersion          string
	LogRequests         bool
}

func loadConfig() (config, error) {
	cfg := config{
		Port:                envOr("PORT", "8080"),
		DatabaseURL:         os.Getenv("DATABASE_URL"),
		RedisAddr:           envOr("REDIS_ADDR", "redis:6379"),
		DBConnectRetries:    envInt("DB_CONNECT_RETRIES", 0),
		DBConnectRetryDelay: time.Duration(envInt("DB_CONNECT_RETRY_DELAY_MS", 1000)) * time.Millisecond,
		EnableDebug:         strings.EqualFold(os.Getenv("ENABLE_DEBUG"), "true"),
		CanarySecret:        os.Getenv("CANARY_SECRET"),
		InstanceID:          os.Getenv("INSTANCE_ID"),
		AppVersion:          envOr("APP_VERSION", "dev"),
		LogRequests:         envBoolDefaultTrue("LOG_REQUESTS"),
	}
	if cfg.DatabaseURL == "" {
		return config{}, fmt.Errorf("DATABASE_URL is required")
	}
	if cfg.InstanceID == "" {
		host, err := os.Hostname()
		if err != nil {
			host = "unknown"
		}
		cfg.InstanceID = host
	}
	return cfg, nil
}

func envOr(key, def string) string {
	v := os.Getenv(key)
	if v == "" {
		return def
	}
	return v
}

func envInt(key string, def int) int {
	raw := os.Getenv(key)
	if raw == "" {
		return def
	}
	n, err := strconv.Atoi(raw)
	if err != nil {
		return def
	}
	return n
}

func envBoolDefaultTrue(key string) bool {
	raw := os.Getenv(key)
	if raw == "" {
		return true
	}
	return !strings.EqualFold(raw, "false")
}

func runHealthcheck() int {
	port := envOr("PORT", "8080")
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, "http://127.0.0.1:"+port+"/health", nil)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		return 1
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		return 1
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return 1
	}
	return 0
}

func main() {
	if len(os.Args) > 1 && os.Args[1] == "healthcheck" {
		os.Exit(runHealthcheck())
	}

	cfg, err := loadConfig()
	if err != nil {
		logJSON("error", "config error", map[string]any{"err": err.Error()})
		os.Exit(1)
	}

	ctx := context.Background()
	pg, err := connectPostgres(ctx, cfg.DatabaseURL, cfg.DBConnectRetries, cfg.DBConnectRetryDelay)
	if err != nil {
		logJSON("error", "postgres unreachable", map[string]any{"err": err.Error()})
		os.Exit(1)
	}

	st := &store{
		pg:    pg,
		redis: connectRedis(cfg.RedisAddr),
	}
	defer st.close()

	if err := st.ensureSchema(ctx); err != nil {
		logJSON("error", "schema failed", map[string]any{"err": err.Error()})
		os.Exit(1)
	}

	rctx, rcancel := context.WithTimeout(ctx, depTimeout)
	if err := st.pingRedis(rctx); err != nil {
		logJSON("error", "redis unreachable at startup; continuing", map[string]any{"err": err.Error()})
	}
	rcancel()

	srvApp := &server{
		cfg:     cfg,
		store:   st,
		started: time.Now(),
		debug:   cfg.EnableDebug,
	}

	httpSrv := &http.Server{
		Addr:         ":" + cfg.Port,
		Handler:      srvApp.routes(),
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 10 * time.Second,
	}

	errCh := make(chan error, 1)
	go func() {
		logJSON("info", "listening", map[string]any{"port": cfg.Port, "version": cfg.AppVersion})
		errCh <- httpSrv.ListenAndServe()
	}()

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGTERM, syscall.SIGINT)

	select {
	case err := <-errCh:
		if err != nil && err != http.ErrServerClosed {
			logJSON("error", "server error", map[string]any{"err": err.Error()})
			os.Exit(1)
		}
	case <-sigCh:
		logJSON("info", "shutdown started", nil)
		sctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		_ = httpSrv.Shutdown(sctx)
		cancel()
		logJSON("info", "shutdown complete", nil)
	}
}
