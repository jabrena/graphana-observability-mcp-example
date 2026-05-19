# graphana-observability-mcp-example

Calculator API with OpenTelemetry export to Grafana LGTM (metrics + traces).

## Run with Docker Compose

From the repository root:

```bash
docker compose up --build
docker compose down
```

| Service | URL |
|---------|-----|
| Calculator API | http://localhost:8080 |
| Grafana | http://localhost:3000 (admin / admin) |
| OTLP (HTTP) | http://localhost:4318 |

Pre-provisioned Grafana dashboards (folder **Spring Boot**):

| Dashboard | ID | Focus |
|-----------|-----|--------|
| JVM (Micrometer) | 4701 | JVM memory, GC, threads |
| Spring Boot HTTP | 20820 | HTTP latency and status codes |
| Spring Boot Observability | 17175 | Metrics, logs, and traces |

## Generate traffic

Generate traffic:

```bash
curl -X POST http://localhost:8080/api/v1/sum \
  -H 'Content-Type: application/json' \
  -d '{"operator1": 1, "operator2": 2}'

curl -X POST http://localhost:8080/api/v1/div \
  -H 'Content-Type: application/json' \
  -d '{"operator1": 1, "operator2": 0}'
```

## Fuzz testing (CATS)

[CATS](https://endava.github.io/cats/) runs contract-driven negative tests from
`service/src/main/resources/openapi/openapi.yaml` against a running API.
The runner builds and uses the image from `cats/Dockerfile` (requires Docker).

Start the stack (or `./mvnw spring-boot:run` in `service/`), then:

```bash
chmod +x run-cats-fuzz.sh
./run-cats-fuzz.sh
```

| Variable | Default | Purpose |
|----------|---------|---------|
| `SERVER` | `http://localhost:8080` | API base URL (rewritten to `host.docker.internal` inside the container) |
| `CATS_MODE` | `blackbox` | `blackbox` (5xx only), `openapi` (contract checks), or `random` (continuous mutations) |
| `CATS_IMAGE` | `calculator-cats:13.8.0` | Docker image tag built from `cats/Dockerfile` |
| `CATS_REPORT_FORMAT` | `HTML_JS` | `HTML_JS` (interactive dashboard), `HTML_ONLY` (no JS), or `JUNIT` (CI) |
| `REPORT_DIR` | `cats/cats-report` | CATS report output directory |

Reports: open `cats/cats-report/index.html` after a run, or serve it locally:

```bash
./run-cats-fuzz.sh --report
# http://127.0.0.1:8000/index.html (JDK 18+ jwebserver; override with CATS_REPORT_PORT)
```

For JUnit XML only, use `CATS_REPORT_FORMAT=JUNIT ./run-cats-fuzz.sh` (writes
`junit.xml`, no `index.html`).

OpenAPI contract mode (validates documented status codes; may warn until error schemas align):

```bash
./run-cats-fuzz.sh --openapi
```

Continuous random mutation fuzzing (all contract paths by default, 60s per path):

```bash
./run-cats-fuzz.sh --random

# Optional tuning
CATS_RANDOM_SECONDS=120 CATS_SEED=42 ./run-cats-fuzz.sh --random
CATS_RANDOM_PATH=/api/v1/div CATS_RANDOM_MUTATIONS=1000 ./run-cats-fuzz.sh --random
```

You can still set `CATS_MODE=openapi` or `CATS_MODE=random` instead of flags.
