package main

import (
	"encoding/json"
	"os"
	"time"
)

func logJSON(level, msg string, fields map[string]any) {
	rec := map[string]any{
		"ts":    time.Now().UTC().Format(time.RFC3339Nano),
		"level": level,
		"msg":   msg,
	}
	for k, v := range fields {
		rec[k] = v
	}
	enc := json.NewEncoder(os.Stdout)
	_ = enc.Encode(rec)
}
