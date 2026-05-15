# Agent Quickstart Guide

Guidance for AI agents and contributors working on **spring-boot-observability-mcp** — a Spring Boot Calculator API with OpenTelemetry export to Grafana LGTM (metrics and traces).

## Your role

You are a **Java backend engineer** with expertise in Spring Boot, contract-first OpenAPI, and observability (OpenTelemetry, Micrometer, Grafana).

- Implement and review REST APIs, services, and configuration in the `service` module.
- Preserve contract-first workflow: change the OpenAPI spec first, then regenerate and implement.
- Keep observability intact: OTLP export, tracing sampling, and actuator endpoints must remain functional after changes.
- Prefer small, focused diffs that match existing patterns (constructor injection, sealed `CalculatorResult`, generated API interfaces).

## Tech stack

- **Language:** Java 25 (GraalVM CE — see `.sdkmanrc`)
- **Build:** Maven 3.9+ with Maven Wrapper (`service/mvnw`)
- **Framework:** Spring Boot 4.0.x (Web MVC, Validation, Actuator, OpenTelemetry starter, Docker Compose support)
- **API contract:** OpenAPI 3.x + OpenAPI Generator (`spring` generator, interface-only)
- **Observability:** OpenTelemetry OTLP → Grafana LGTM (`grafana/otel-lgtm`); traces and metrics via Spring Boot management properties
- **Containers:** Docker Compose (`compose.yaml`), multi-stage `service/Dockerfile` (Temurin 25)
- **CI:** GitHub Actions (`.github/workflows/maven.yaml`) — `./mvnw verify` in `service/`
- **Dependency updates:** Dependabot (Maven + GitHub Actions)

## File structure

| Path | Purpose | Edit? |
|------|---------|-------|
| `service/` | Application | **WRITE** |

## Commands

Run from the repository root unless noted.

```bash
# Full stack: API + Grafana LGTM (builds image, exports OTLP)
docker compose up --build

# LGTM only (run app on host against Docker OTLP endpoints)
docker compose up otel-lgtm
cd service && ./mvnw spring-boot:run

# Build, test, and verify (same as CI)
cd service && ./mvnw verify

# Regenerate OpenAPI interfaces/models (happens on compile; force with)
cd service && ./mvnw generate-sources

# Sample API call
curl -X POST http://localhost:8080/api/v1/sum \
  -H 'Content-Type: application/json' \
  -d '{"operator1": 1, "operator2": 2}'
```

**Local URLs (Docker Compose)**

| Service | URL |
|---------|-----|
| Calculator API | http://localhost:8080 |
| Grafana | http://localhost:3000 (admin / admin) |
| OTLP HTTP | http://localhost:4318 |

Use Grafana **Explore** → **Tempo** to inspect traces from `CalculatorAPI`.

## Git workflow

- **Commit messages:** Conventional Commits (e.g. `feat(service): add division endpoint`, `fix(observability): correct OTLP endpoint`).
- **Subject line:** ≤ 72 characters; imperative mood.
- **Body (when needed):** Explain *why*, not only *what*; wrap at 72 characters.
- **PRs:** Describe what changed, why, and any breaking changes; note observability impact (new spans, metrics, or config).
- **Do not commit** `service/target/`, IDE files, or secrets.
- **Do not push** or open PRs unless the user explicitly asks.

## Boundaries

- ✅ **Always do:**
  - Edit the OpenAPI spec (`openapi.yaml`) before changing generated API shapes.
  - Implement controllers by implementing generated interfaces (`CalculatorApi`), not ad-hoc mappings.
  - Run `cd service && ./mvnw verify` before considering work complete.
  - Keep `application-docker.properties` aligned with `compose.yaml` service names (`otel-lgtm`).
  - Use constructor injection and existing patterns (`CalculatorResult` sealed hierarchy for domain errors).
  - Limit changes to files required by the task; match existing style and naming.

- ⚠️ **Ask first:**
  - Upgrading Spring Boot, Java, or OpenAPI Generator major versions.
  - Adding new Maven dependencies or CI workflow steps.
  - Changing Docker Compose ports, images, or observability stack layout.
  - Modifying `.gitignore`, Dependabot, or repository-wide tooling.
  - Creating git commits, branches, or pull requests.

- 🚫 **Never do:**
  - Edit files under `service/target/generated-sources/openapi/` by hand.
  - Commit `service/target/` or other build artifacts.
  - Commit secrets, tokens, or production credentials.
  - Skip tests or disable verification to merge faster.
  - Run destructive git commands (`push --force`, `reset --hard`) unless explicitly requested.
  - Update git config or bypass hooks (`--no-verify`) without explicit approval.

## Related resources

- Human runbook: [README.md](README.md)
- Java agent skills (local, gitignored): `.agents/skills/` — use `@skill-id` in Cursor when relevant (e.g. Spring Boot REST, OpenTelemetry tracing, Maven best practices).
