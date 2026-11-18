package main

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"
)

const (
	depTimeout   = 2 * time.Second
	readyTimeout = 1 * time.Second
	schemaSQL    = `CREATE TABLE IF NOT EXISTS events (
  id         BIGSERIAL PRIMARY KEY,
  seq        BIGINT NOT NULL UNIQUE,
  payload    TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
)`
	insertSQL       = `INSERT INTO events (seq, payload) VALUES ($1, $2)`
	maxSeqSQL       = `SELECT seq, payload, created_at FROM events ORDER BY seq DESC LIMIT 1`
	statsSQL        = `SELECT COUNT(*), COALESCE(MAX(seq), 0) FROM events`
	redisCounterKey = "counter"
)

var errUniqueSeq = errors.New("duplicate seq")

type store struct {
	pg    *pgxpool.Pool
	redis *redis.Client
}

func connectPostgres(ctx context.Context, url string, retries int, delay time.Duration) (*pgxpool.Pool, error) {
	cfg, err := pgxpool.ParseConfig(url)
	if err != nil {
		return nil, fmt.Errorf("parse DATABASE_URL: %w", err)
	}
	cfg.MaxConns = 10

	var last error
	attempts := retries + 1
	for i := 0; i < attempts; i++ {
		pool, err := pgxpool.NewWithConfig(ctx, cfg)
		if err != nil {
			last = err
		} else {
			pctx, cancel := context.WithTimeout(ctx, depTimeout)
			err = pool.Ping(pctx)
			cancel()
			if err == nil {
				return pool, nil
			}
			pool.Close()
			last = err
		}
		if i+1 < attempts {
			time.Sleep(delay)
		}
	}
	return nil, last
}

func connectRedis(addr string) *redis.Client {
	return redis.NewClient(&redis.Options{
		Addr: addr,
	})
}

func (s *store) ensureSchema(ctx context.Context) error {
	_, err := s.pg.Exec(ctx, schemaSQL)
	return err
}

func (s *store) pingPostgres(ctx context.Context) error {
	return s.pg.Ping(ctx)
}

func (s *store) pingRedis(ctx context.Context) error {
	return s.redis.Ping(ctx).Err()
}

func (s *store) insertEvent(ctx context.Context, seq int64, payload string) error {
	_, err := s.pg.Exec(ctx, insertSQL, seq, payload)
	if err == nil {
		return nil
	}
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) && pgErr.Code == "23505" {
		return errUniqueSeq
	}
	return err
}

type eventRow struct {
	Seq       int64     `json:"seq"`
	Payload   string    `json:"payload"`
	CreatedAt time.Time `json:"created_at"`
}

func (s *store) latestEvent(ctx context.Context) (eventRow, error) {
	var row eventRow
	err := s.pg.QueryRow(ctx, maxSeqSQL).Scan(&row.Seq, &row.Payload, &row.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return eventRow{}, err
	}
	return row, err
}

func (s *store) stats(ctx context.Context) (count, maxSeq int64, err error) {
	err = s.pg.QueryRow(ctx, statsSQL).Scan(&count, &maxSeq)
	return
}

func (s *store) incrCounter(ctx context.Context) (int64, error) {
	return s.redis.Incr(ctx, redisCounterKey).Result()
}

func (s *store) getCounter(ctx context.Context) (int64, error) {
	n, err := s.redis.Get(ctx, redisCounterKey).Int64()
	if errors.Is(err, redis.Nil) {
		return 0, nil
	}
	return n, err
}

func (s *store) close() {
	if s.pg != nil {
		s.pg.Close()
	}
	if s.redis != nil {
		_ = s.redis.Close()
	}
}
