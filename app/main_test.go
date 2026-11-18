package main

import (
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestParseInsertBodyOK(t *testing.T) {
	body, err := parseInsertBody(strings.NewReader(`{"seq":1,"payload":"hello"}`))
	if err != nil {
		t.Fatal(err)
	}
	if body.Seq != 1 || body.Payload != "hello" {
		t.Fatalf("got %+v", body)
	}
}

func TestParseInsertBodyBadJSON(t *testing.T) {
	_, err := parseInsertBody(strings.NewReader(`not json`))
	if err == nil {
		t.Fatal("expected error")
	}
}

func TestParseInsertBodyPayloadTooLarge(t *testing.T) {
	payload := strings.Repeat("a", 1025)
	_, err := parseInsertBody(strings.NewReader(`{"seq":1,"payload":"` + payload + `"}`))
	if err == nil {
		t.Fatal("expected error")
	}
}

func TestParseInsertBodyPayloadAtLimit(t *testing.T) {
	payload := strings.Repeat("a", 1024)
	_, err := parseInsertBody(strings.NewReader(`{"seq":1,"payload":"` + payload + `"}`))
	if err != nil {
		t.Fatal(err)
	}
}

func TestDebugOffReturns404(t *testing.T) {
	s := &server{cfg: config{AppVersion: "test"}, debug: false}
	req := httptest.NewRequest(http.MethodGet, "/debug/canary", nil)
	rec := httptest.NewRecorder()
	s.routes().ServeHTTP(rec, req)
	if rec.Code != http.StatusNotFound {
		t.Fatalf("status %d", rec.Code)
	}
	if rec.Header().Get("X-App-Version") != "test" {
		t.Fatal("missing version header")
	}
}

func TestHealthcheckSubcommand(t *testing.T) {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = io.WriteString(w, `{"status":"ok"}`)
	})
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	srv := &http.Server{Handler: mux}
	go srv.Serve(ln)
	defer srv.Close()

	_, port, err := net.SplitHostPort(ln.Addr().String())
	if err != nil {
		t.Fatal(err)
	}
	t.Setenv("PORT", port)
	if code := runHealthcheck(); code != 0 {
		t.Fatalf("want 0 got %d", code)
	}
}

func TestHealthcheckSubcommandFail(t *testing.T) {
	t.Setenv("PORT", "1")
	if code := runHealthcheck(); code != 1 {
		t.Fatalf("want 1 got %d", code)
	}
}

func TestLoadConfigRequiresDatabaseURL(t *testing.T) {
	t.Setenv("DATABASE_URL", "")
	_, err := loadConfig()
	if err == nil {
		t.Fatal("expected error")
	}
}

func TestLoadConfigOK(t *testing.T) {
	t.Setenv("DATABASE_URL", "postgres://app:x@postgres:5432/appdb")
	t.Setenv("PORT", "9090")
	t.Setenv("ENABLE_DEBUG", "true")
	t.Setenv("LOG_REQUESTS", "false")
	cfg, err := loadConfig()
	if err != nil {
		t.Fatal(err)
	}
	if cfg.Port != "9090" || !cfg.EnableDebug || cfg.LogRequests {
		t.Fatalf("got %+v", cfg)
	}
}

func TestHealthNeverTouchesStore(t *testing.T) {
	s := &server{cfg: config{AppVersion: "test"}}
	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	rec := httptest.NewRecorder()
	s.routes().ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("status %d", rec.Code)
	}
}
