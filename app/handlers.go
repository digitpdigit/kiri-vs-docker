package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/jackc/pgx/v5"
)

const maxPayloadBytes = 1024

type insertBody struct {
	Seq     int64  `json:"seq"`
	Payload string `json:"payload"`
}

func parseInsertBody(r io.Reader) (insertBody, error) {
	var body insertBody
	dec := json.NewDecoder(r)
	if err := dec.Decode(&body); err != nil {
		return insertBody{}, fmt.Errorf("bad body")
	}
	if len(body.Payload) > maxPayloadBytes {
		return insertBody{}, fmt.Errorf("payload over 1 KB")
	}
	return body, nil
}

type server struct {
	cfg       config
	store     *store
	started   time.Time
	debug     bool
	allocMu   sync.Mutex
	allocHold []byte
}

func (s *server) routes() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", s.handleHealth)
	mux.HandleFunc("GET /ready", s.handleReady)
	mux.HandleFunc("GET /db", s.handleGetDB)
	mux.HandleFunc("POST /db", s.handlePostDB)
	mux.HandleFunc("GET /cache", s.handleCache)
	mux.HandleFunc("GET /stats", s.handleStats)
	if s.debug {
		mux.HandleFunc("GET /debug/log", s.handleDebugLog)
		mux.HandleFunc("POST /debug/alloc", s.handleDebugAlloc)
		mux.HandleFunc("DELETE /debug/alloc", s.handleDebugAllocRelease)
		mux.HandleFunc("GET /debug/panic", s.handleDebugPanic)
		mux.HandleFunc("GET /debug/canary", s.handleDebugCanary)
	}
	return s.wrap(mux)
}

func (s *server) wrap(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("X-App-Version", s.cfg.AppVersion)
		start := time.Now()
		rw := &statusWriter{ResponseWriter: w, status: http.StatusOK}
		next.ServeHTTP(rw, r)
		if s.cfg.LogRequests {
			logJSON("info", "request", map[string]any{
				"path":        r.URL.Path,
				"status":      rw.status,
				"duration_ms": time.Since(start).Milliseconds(),
			})
		}
	})
}

type statusWriter struct {
	http.ResponseWriter
	status int
}

func (w *statusWriter) WriteHeader(code int) {
	w.status = code
	w.ResponseWriter.WriteHeader(code)
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

func (s *server) handleHealth(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (s *server) handleReady(w http.ResponseWriter, r *http.Request) {
	pg := "ok"
	rd := "ok"
	ctx, cancel := context.WithTimeout(r.Context(), readyTimeout)
	if err := s.store.pingPostgres(ctx); err != nil {
		pg = "down"
	}
	cancel()
	ctx, cancel = context.WithTimeout(r.Context(), readyTimeout)
	if err := s.store.pingRedis(ctx); err != nil {
		rd = "down"
	}
	cancel()
	body := map[string]string{"postgres": pg, "redis": rd}
	if pg != "ok" || rd != "ok" {
		writeJSON(w, http.StatusServiceUnavailable, body)
		return
	}
	writeJSON(w, http.StatusOK, body)
}

func (s *server) handleGetDB(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), depTimeout)
	defer cancel()
	row, err := s.store.latestEvent(ctx)
	if errors.Is(err, pgx.ErrNoRows) {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "empty"})
		return
	}
	if err != nil {
		logJSON("error", "db get failed", map[string]any{"err": err.Error()})
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "postgres down"})
		return
	}
	writeJSON(w, http.StatusOK, row)
}

func (s *server) handlePostDB(w http.ResponseWriter, r *http.Request) {
	body, err := parseInsertBody(r.Body)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": err.Error()})
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), depTimeout)
	defer cancel()
	err = s.store.insertEvent(ctx, body.Seq, body.Payload)
	if errors.Is(err, errUniqueSeq) {
		writeJSON(w, http.StatusConflict, map[string]string{"error": "duplicate seq"})
		return
	}
	if err != nil {
		logJSON("error", "db insert failed", map[string]any{"err": err.Error()})
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "postgres down"})
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"seq": body.Seq, "payload": body.Payload})
}

func (s *server) handleCache(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), depTimeout)
	defer cancel()
	n, err := s.store.incrCounter(ctx)
	if err != nil {
		logJSON("error", "redis incr failed", map[string]any{"err": err.Error()})
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "redis down"})
		return
	}
	writeJSON(w, http.StatusOK, map[string]int64{"counter": n})
}

func (s *server) handleStats(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), depTimeout)
	defer cancel()
	count, maxSeq, err := s.store.stats(ctx)
	if err != nil {
		logJSON("error", "stats db failed", map[string]any{"err": err.Error()})
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "postgres down"})
		return
	}
	counter, err := s.store.getCounter(ctx)
	if err != nil {
		logJSON("error", "stats redis failed", map[string]any{"err": err.Error()})
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "redis down"})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"row_count":   count,
		"max_seq":     maxSeq,
		"counter":     counter,
		"instance_id": s.cfg.InstanceID,
		"version":     s.cfg.AppVersion,
		"uptime_s":    int64(time.Since(s.started).Seconds()),
	})
}

func (s *server) handleDebugLog(w http.ResponseWriter, r *http.Request) {
	n := queryInt(r, "n", 1000)
	size := queryInt(r, "size", 200)
	if n > 5_000_000 {
		n = 5_000_000
	}
	if n < 0 {
		n = 0
	}
	if size < 0 {
		size = 0
	}
	line := strings.Repeat("x", size)
	for i := 0; i < n; i++ {
		logJSON("info", "debug log", map[string]any{"i": i, "pad": line})
	}
	writeJSON(w, http.StatusOK, map[string]int{"n": n, "size": size})
}

func (s *server) handleDebugAlloc(w http.ResponseWriter, r *http.Request) {
	mb := queryInt(r, "mb", 0)
	if mb < 0 {
		mb = 0
	}
	n := mb * 1024 * 1024
	buf := make([]byte, n)
	for i := 0; i < len(buf); i += 4096 {
		buf[i] = 1
	}
	s.allocMu.Lock()
	s.allocHold = buf
	s.allocMu.Unlock()
	writeJSON(w, http.StatusOK, map[string]int{"mb": mb})
}

func (s *server) handleDebugAllocRelease(w http.ResponseWriter, _ *http.Request) {
	s.allocMu.Lock()
	s.allocHold = nil
	s.allocMu.Unlock()
	writeJSON(w, http.StatusOK, map[string]string{"status": "released"})
}

func (s *server) handleDebugPanic(w http.ResponseWriter, _ *http.Request) {
	go func() {
		panic("debug panic")
	}()
	writeJSON(w, http.StatusOK, map[string]string{"status": "panic scheduled"})
}

func (s *server) handleDebugCanary(w http.ResponseWriter, _ *http.Request) {
	logJSON("info", "canary secret", map[string]any{"secret": s.cfg.CanarySecret})
	logJSON("info", "canary dsn", map[string]any{"url": "postgres://user:CANARY-PASSWORD-123@host/db"})
	writeJSON(w, http.StatusOK, map[string]string{"status": "logged"})
}

func queryInt(r *http.Request, key string, def int) int {
	raw := r.URL.Query().Get(key)
	if raw == "" {
		return def
	}
	n, err := strconv.Atoi(raw)
	if err != nil {
		return def
	}
	return n
}
