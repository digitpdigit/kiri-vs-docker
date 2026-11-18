package main

import (
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"net/http"
	"os"
	"time"
)

func main() {
	base := flag.String("url", "http://127.0.0.1:8080", "app base URL")
	n := flag.Int("n", 10, "number of seq values to acknowledge")
	rate := flag.Float64("rate", 10, "POSTs per second")
	ackPath := flag.String("ack", "ack.log", "ack log path on this machine")
	retries := flag.Int("retries", 5, "retries per seq on non-201")
	flag.Parse()

	f, err := os.OpenFile(*ackPath, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o644)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	defer f.Close()

	client := &http.Client{Timeout: 5 * time.Second}
	interval := time.Duration(0)
	if *rate > 0 {
		interval = time.Second / time.Duration(*rate)
	}

	for seq := int64(1); seq <= int64(*n); seq++ {
		ok := false
		for attempt := 0; attempt <= *retries; attempt++ {
			status, reason := postDB(client, *base, seq)
			ts := time.Now().UTC().Format(time.RFC3339Nano)
			if status == http.StatusCreated {
				fmt.Fprintf(f, "%d\t201\t%s\n", seq, ts)
				_ = f.Sync()
				ok = true
				break
			}
			fmt.Fprintf(f, "%d\tFAILED\t%s\t%s\n", seq, reason, ts)
			_ = f.Sync()
			time.Sleep(200 * time.Millisecond)
		}
		if !ok {
			fmt.Fprintf(os.Stderr, "seq %d never acknowledged\n", seq)
			os.Exit(1)
		}
		if interval > 0 && seq < int64(*n) {
			time.Sleep(interval)
		}
	}
}

func postDB(client *http.Client, base string, seq int64) (int, string) {
	body, _ := json.Marshal(map[string]any{"seq": seq, "payload": fmt.Sprintf("p-%d", seq)})
	resp, err := client.Post(base+"/db", "application/json", bytes.NewReader(body))
	if err != nil {
		return 0, err.Error()
	}
	defer resp.Body.Close()
	b, _ := io.ReadAll(io.LimitReader(resp.Body, 512))
	if resp.StatusCode != http.StatusCreated {
		return resp.StatusCode, fmt.Sprintf("status=%d body=%s", resp.StatusCode, bytes.TrimSpace(b))
	}
	return resp.StatusCode, ""
}
