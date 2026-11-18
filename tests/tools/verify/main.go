package main

import (
	"bufio"
	"context"
	"flag"
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
)

func main() {
	ackPath := flag.String("ack", "ack.log", "ack log path")
	dbURL := flag.String("database-url", os.Getenv("DATABASE_URL"), "Postgres DSN")
	seqFile := flag.String("seq-file", "", "file of seq values, one per line (from psql -Atc)")
	flag.Parse()

	acked, err := loadAcked(*ackPath)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}

	var present map[int64]struct{}
	if *seqFile != "" {
		present, err = loadSeqFile(*seqFile)
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
	} else {
		if *dbURL == "" {
			fmt.Fprintln(os.Stderr, "DATABASE_URL, -database-url, or -seq-file required")
			os.Exit(1)
		}
		present, err = loadFromDB(*dbURL)
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
	}

	var max int64
	for seq := range present {
		if seq > max {
			max = seq
		}
	}
	for seq := range acked {
		if seq > max {
			max = seq
		}
	}

	ackedMissing := 0
	for seq := range acked {
		if _, ok := present[seq]; !ok {
			ackedMissing++
			fmt.Printf("ACKED_BUT_MISSING seq=%d\n", seq)
		}
	}

	presentNotAcked := 0
	for seq := range present {
		if _, ok := acked[seq]; !ok {
			presentNotAcked++
		}
	}

	gaps := 0
	for seq := int64(1); seq <= max; seq++ {
		_, inAck := acked[seq]
		_, inDB := present[seq]
		if !inAck && !inDB {
			gaps++
		}
	}

	fmt.Printf("ACKED_BUT_MISSING: %d\n", ackedMissing)
	fmt.Printf("PRESENT_NOT_ACKED: %d\n", presentNotAcked)
	fmt.Printf("GAPS: %d\n", gaps)
	if ackedMissing > 0 {
		fmt.Println("RESULT: FAIL")
		os.Exit(1)
	}
	fmt.Println("RESULT: PASS")
}

func loadFromDB(dbURL string) (map[int64]struct{}, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	conn, err := pgx.Connect(ctx, dbURL)
	if err != nil {
		return nil, err
	}
	defer conn.Close(ctx)
	rows, err := conn.Query(ctx, "SELECT seq FROM events")
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	present := map[int64]struct{}{}
	for rows.Next() {
		var seq int64
		if err := rows.Scan(&seq); err != nil {
			return nil, err
		}
		present[seq] = struct{}{}
	}
	return present, rows.Err()
}

func loadSeqFile(path string) (map[int64]struct{}, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	out := map[int64]struct{}{}
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if line == "" {
			continue
		}
		seq, err := strconv.ParseInt(line, 10, 64)
		if err != nil {
			continue
		}
		out[seq] = struct{}{}
	}
	return out, sc.Err()
}

func loadAcked(path string) (map[int64]struct{}, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	out := map[int64]struct{}{}
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := sc.Text()
		parts := strings.Split(line, "\t")
		if len(parts) < 2 {
			continue
		}
		if parts[1] != "201" {
			continue
		}
		seq, err := strconv.ParseInt(parts[0], 10, 64)
		if err != nil {
			continue
		}
		out[seq] = struct{}{}
	}
	return out, sc.Err()
}
