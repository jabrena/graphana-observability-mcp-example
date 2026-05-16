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
