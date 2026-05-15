# spring-boot-observability-mcp

Calculator API with OpenTelemetry export to Grafana LGTM (metrics + traces).

## Run with Docker Compose

Install the [Loki Docker driver](https://grafana.com/docs/loki/latest/send-data/docker-driver/) once (required for log panels):

```bash
docker plugin install grafana/loki-docker-driver:latest --alias loki --grant-all-permissions
```

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

Generate traffic:

```bash
curl -X POST http://localhost:8080/api/v1/sum \
  -H 'Content-Type: application/json' \
  -d '{"operator1": 1, "operator2": 2}'

curl -X POST http://localhost:8080/api/v1/div \
  -H 'Content-Type: application/json' \
  -d '{"operator1": 1, "operator2": 0}'
```

In Grafana, open **Explore** and query **Tempo** for traces from `CalculatorAPI`, or use **Spring Boot Observability** for correlated metrics, logs, and traces.

## Run locally (app on host, LGTM in Docker)

```bash
docker compose up otel-lgtm
cd service && ./mvnw spring-boot:run
```

Spring Boot Docker Compose support auto-wires OTLP endpoints to the running `otel-lgtm` container.

## Build and test

```bash
cd service && ./mvnw verify
```
