# Test app

Boring Go HTTP app for comparing Kiri and Docker Engine. The same image is used on both runtimes.

## Build once

Do not rebuild for each engine. Build, then `docker save` and load the same image into both engines. The two engines report different IDs for it (manifest-list digest vs config digest), so compare image content, not the ID.

```
docker build -t kiri-vs-docker-app:local ./app
docker save kiri-vs-docker-app:local -o app-image.tar
```

## Run (Docker control)

From repo root:

```
docker compose -f compose/compose.yml --env-file compose/.env.example up -d --build
```

Debug endpoints (tests 14, 29, 31 only):

```
docker compose -f compose/compose.yml -f compose/compose.debug.yml --env-file compose/.env.example up -d
```

Healthcheck (no shell in the image): `/app healthcheck` → GET `http://127.0.0.1:$PORT/health`.

## Env vars

| Variable                    | Default      | Meaning                                       |
| --------------------------- | ------------ | --------------------------------------------- |
| `PORT`                      | `8080`       | HTTP listen port                              |
| `DATABASE_URL`              | required     | Postgres DSN                                  |
| `REDIS_ADDR`                | `redis:6379` | Redis address                                 |
| `DB_CONNECT_RETRIES`        | `0`          | Postgres startup retries; `0` = fail fast     |
| `DB_CONNECT_RETRY_DELAY_MS` | `1000`       | Delay between retries                         |
| `ENABLE_DEBUG`              | `false`      | Enable `/debug/*`                             |
| `CANARY_SECRET`             | empty        | Fake secret for `/debug/canary`               |
| `INSTANCE_ID`               | hostname     | Reported in `/stats`                          |
| `APP_VERSION`               | `dev`        | `/stats` and `X-App-Version`                  |
| `LOG_REQUESTS`              | `true`       | Per-request info logs; set `false` under load |

Fake credentials only. Never real data.
