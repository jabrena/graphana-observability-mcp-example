#!/usr/bin/env bash
# Contract-driven API fuzzing with CATS (https://endava.github.io/cats/).
# Runs CATS in Docker (see cats/Dockerfile). API must be reachable from the container.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CATS_DIR="${REPO_ROOT}/cats"
SERVICE_DIR="${REPO_ROOT}/service"

CONTRACT="${CONTRACT:-${SERVICE_DIR}/src/main/resources/openapi/openapi.yaml}"
SERVER="${SERVER:-http://localhost:8080}"
HEALTH_URL="${HEALTH_URL:-${SERVER}/actuator/health}"
CATS_VERSION="${CATS_VERSION:-13.8.0}"
CATS_IMAGE="${CATS_IMAGE:-calculator-cats:${CATS_VERSION}}"
CATS_REBUILD="${CATS_REBUILD:-0}"
CATS_MODE="${CATS_MODE:-blackbox}"
CATS_REPORT_FORMAT="${CATS_REPORT_FORMAT:-HTML_JS}"
REPORT_DIR="${REPORT_DIR:-${CATS_DIR}/cats-report}"
WAIT_TIMEOUT_SEC="${WAIT_TIMEOUT_SEC:-60}"
CATS_SEED="${CATS_SEED:-}"
CATS_RANDOM_PATH="${CATS_RANDOM_PATH:-}"
CATS_RANDOM_SECONDS="${CATS_RANDOM_SECONDS:-60}"
CATS_RANDOM_MUTATIONS="${CATS_RANDOM_MUTATIONS:-}"
CATS_RANDOM_MATCH_CODES="${CATS_RANDOM_MATCH_CODES:-500}"
CATS_REPORT_PORT="${CATS_REPORT_PORT:-8000}"
CATS_REPORT_BIND="${CATS_REPORT_BIND:-127.0.0.1}"
CATS_COMPOSE_SERVICE="${CATS_COMPOSE_SERVICE:-calculator-api}"
CATS_COMPOSE_NETWORK="${CATS_COMPOSE_NETWORK:-}"
RUN_REPORT_SERVER=0
CATS_DOCKER_NETWORK=""
SERVER_DOCKER=""

usage() {
  cat <<'EOF'
Usage: run-cats-fuzz.sh [options]

Runs CATS fuzz tests in Docker (cats/Dockerfile) against the OpenAPI contract.
The API must already be listening (for example via docker compose up or
./mvnw spring-boot:run).

Environment variables:
  SERVER                API base URL (default: http://localhost:8080)
  CONTRACT              OpenAPI spec path (default: service/.../openapi.yaml)
  HEALTH_URL            Readiness probe URL on the host (default: SERVER/actuator/health)
  CATS_VERSION          CATS release version (default: 13.8.0)
  CATS_IMAGE            Docker image tag (default: calculator-cats:CATS_VERSION)
  CATS_REBUILD          Set to 1 to force docker build (default: 0)
  CATS_MODE             blackbox | openapi | random (default: blackbox)
  CATS_REPORT_FORMAT    HTML_JS | HTML_ONLY | JUNIT (default: HTML_JS)
  REPORT_DIR            Output directory for reports (default: cats/cats-report)
  CATS_REPORT_PORT      Port for --report jwebserver (default: 8000)
  CATS_REPORT_BIND      Bind address for --report jwebserver (default: 127.0.0.1)
  WAIT_TIMEOUT_SEC      Seconds to wait for HEALTH_URL (default: 60)
  CATS_COMPOSE_SERVICE    Compose service name for in-network fuzzing (default: calculator-api)
  CATS_COMPOSE_NETWORK    Docker network name (auto-detected from compose when empty)

  random mode only:
  CATS_SEED               Seed for cats random (default: CATS default)
  CATS_RANDOM_PATH        Single path to fuzz (default: all contract paths)
  CATS_RANDOM_SECONDS     Stop after N seconds per path (default: 60)
  CATS_RANDOM_MUTATIONS   Stop after N mutations per path (overrides seconds)
  CATS_RANDOM_MATCH_CODES Comma-separated HTTP codes to treat as errors (default: 500)

Modes:
  blackbox   Pre-defined fuzzers; report only 5xx (default)
  openapi    Pre-defined fuzzers; validate responses against the OpenAPI contract
  random     Continuous mutation fuzzing (cats random sub-command)

Options:
  --openapi       Validate responses against the OpenAPI contract
  --random        Continuous mutation fuzzing (cats random)
  --report        Serve REPORT_DIR with Java jwebserver (JDK 18+); no fuzz run
  -h, --help      Show this help

If no mode flag is given, CATS_MODE applies (default: blackbox).
Mode flags (--openapi, --random, --report) cannot be combined.

When SERVER uses localhost, the script rewrites it to host.docker.internal inside
the container so CATS can reach an API running on the host.
EOF
}

parse_args() {
  local mode_from_flag=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        usage
        exit 0
        ;;
      --openapi)
        if [[ -n "${mode_from_flag}" && "${mode_from_flag}" != "openapi" ]]; then
          echo "Cannot combine --openapi with --${mode_from_flag}" >&2
          exit 2
        fi
        mode_from_flag=openapi
        ;;
      --random)
        if [[ -n "${mode_from_flag}" && "${mode_from_flag}" != "random" ]]; then
          echo "Cannot combine --random with --${mode_from_flag}" >&2
          exit 2
        fi
        mode_from_flag=random
        ;;
      --report)
        if [[ -n "${mode_from_flag}" && "${mode_from_flag}" != "report" ]]; then
          echo "Cannot combine --report with --${mode_from_flag}" >&2
          exit 2
        fi
        mode_from_flag=report
        ;;
      *)
        echo "Unknown option: $1" >&2
        usage >&2
        exit 2
        ;;
    esac
    shift
  done

  if [[ "${mode_from_flag}" == "report" ]]; then
    RUN_REPORT_SERVER=1
  elif [[ -n "${mode_from_flag}" ]]; then
    CATS_MODE="${mode_from_flag}"
  fi
}

parse_args "$@"

# Backward compatibility for renamed mode.
if [[ "${RUN_REPORT_SERVER}" != "1" && "${CATS_MODE}" == "context" ]]; then
  echo "Note: CATS_MODE=context is deprecated; use --openapi or CATS_MODE=openapi" >&2
  CATS_MODE=openapi
fi

resolve_report_dir() {
  if [[ -d "${REPORT_DIR}" ]]; then
    REPORT_DIR="$(cd "${REPORT_DIR}" && pwd)"
  else
    local parent
    parent="$(dirname "${REPORT_DIR}")"
    if [[ -d "${parent}" ]]; then
      REPORT_DIR="$(cd "${parent}" && pwd)/$(basename "${REPORT_DIR}")"
    elif [[ "${REPORT_DIR}" != /* ]]; then
      REPORT_DIR="${REPO_ROOT}/${REPORT_DIR}"
    fi
  fi
}

ensure_report_dir_for_fuzz() {
  REPORT_DIR="$(mkdir -p "${REPORT_DIR}" && cd "${REPORT_DIR}" && pwd)"
}

run_report_server() {
  resolve_report_dir

  if [[ ! -d "${REPORT_DIR}" ]]; then
    echo "Report directory not found: ${REPORT_DIR}" >&2
    echo "Run CATS first, for example: ./run-cats-fuzz.sh --openapi" >&2
    exit 1
  fi

  if [[ ! -f "${REPORT_DIR}/index.html" ]]; then
    echo "Warning: ${REPORT_DIR}/index.html not found." >&2
    echo "Regenerate with HTML_JS (default) or CATS_REPORT_FORMAT=HTML_JS." >&2
  fi

  local -a server_cmd=()
  if command -v jwebserver >/dev/null 2>&1; then
    server_cmd=(jwebserver)
  elif command -v java >/dev/null 2>&1 && java -m jdk.httpserver -h >/dev/null 2>&1; then
    server_cmd=(java -m jdk.httpserver)
  else
    echo "Java 18+ is required: install JDK with jwebserver (or java -m jdk.httpserver)." >&2
    exit 1
  fi

  echo "Serving CATS report: http://${CATS_REPORT_BIND}:${CATS_REPORT_PORT}/index.html"
  echo "Directory: ${REPORT_DIR}"
  echo "Press Ctrl+C to stop."
  exec "${server_cmd[@]}" -b "${CATS_REPORT_BIND}" -p "${CATS_REPORT_PORT}" -d "${REPORT_DIR}"
}

to_workspace_path() {
  local abs_path="$1"
  if [[ "${abs_path}" != "${REPO_ROOT}"/* ]]; then
    echo "Path must be inside the repository: ${abs_path}" >&2
    exit 1
  fi
  echo "/workspace/${abs_path#"${REPO_ROOT}/"}"
}

detect_compose_network() {
  if [[ -n "${CATS_COMPOSE_NETWORK}" ]]; then
    CATS_DOCKER_NETWORK="${CATS_COMPOSE_NETWORK}"
    return 0
  fi
  if ! docker compose -f "${REPO_ROOT}/docker-compose.yaml" ps -q "${CATS_COMPOSE_SERVICE}" >/dev/null 2>&1; then
    return 1
  fi
  local container_id
  container_id="$(docker compose -f "${REPO_ROOT}/docker-compose.yaml" ps -q "${CATS_COMPOSE_SERVICE}" 2>/dev/null | head -1)"
  [[ -n "${container_id}" ]] || return 1
  CATS_DOCKER_NETWORK="$(docker inspect -f '{{range $k, $v := .NetworkSettings.Networks}}{{$k}}{{end}}' "${container_id}" 2>/dev/null | tr -d '[:space:]')"
  [[ -n "${CATS_DOCKER_NETWORK}" ]]
}

resolve_server_for_docker() {
  local scheme hostport port
  CATS_DOCKER_NETWORK=""
  if [[ "${SERVER}" =~ ^https?:// ]]; then
    scheme="${SERVER%%://*}"
    hostport="${SERVER#*://}"
    hostport="${hostport%%/*}"
    port="${hostport##*:}"
    if [[ "${port}" == "${hostport}" ]]; then
      port="80"
      [[ "${scheme}" == "https" ]] && port="443"
    fi
  else
    SERVER_DOCKER="${SERVER}"
    return
  fi

  if detect_compose_network; then
    SERVER_DOCKER="${scheme}://${CATS_COMPOSE_SERVICE}:${port}"
    return
  fi

  if [[ "${SERVER}" =~ ^https?://(localhost|127\.0\.0\.1)([:/]|$) ]]; then
    SERVER_DOCKER="${scheme}://host.docker.internal:${port}"
  else
    SERVER_DOCKER="${SERVER}"
  fi
}

warn_host_port_conflict() {
  local port="${1}"
  if [[ -n "${CATS_DOCKER_NETWORK}" ]]; then
    return 0
  fi
  if [[ "${SERVER}" =~ ^https?://(localhost|127\.0\.0\.1) ]]; then
    if lsof -nP -iTCP:"${port}" -sTCP:LISTEN 2>/dev/null | grep -qv 'com.docke'; then
      echo "Warning: a non-Docker process is listening on port ${port}." >&2
      echo "  CATS uses host.docker.internal from Docker; static servers on that port cause false 405 errors." >&2
      echo "  Prefer: docker compose up, or set SERVER to the compose service URL." >&2
    fi
  fi
}

verify_cats_reachability() {
  local probe_url="${SERVER_DOCKER}/actuator/health"
  local -a docker_args=(run --rm --entrypoint sh)
  if [[ -n "${CATS_DOCKER_NETWORK}" ]]; then
    docker_args+=(--network "${CATS_DOCKER_NETWORK}")
  else
    docker_args+=(--add-host=host.docker.internal:host-gateway)
  fi
  if ! docker "${docker_args[@]}" "${CATS_IMAGE}" \
    -c "curl -fsS '${probe_url}' >/dev/null"; then
    echo "CATS container cannot reach ${probe_url}." >&2
    if [[ "${SERVER_DOCKER}" == *host.docker.internal* ]]; then
      echo "Start the API with docker compose, or stop other listeners on the target port." >&2
    fi
    exit 1
  fi
  if ! docker "${docker_args[@]}" "${CATS_IMAGE}" \
    -c "curl -fsS -o /dev/null -w '%{http_code}' -X POST '${SERVER_DOCKER}/api/v1/sum' -H 'Content-Type: application/json' -d '{\"operator1\":1,\"operator2\":2}' | grep -q '^200$'"; then
    echo "CATS container POST probe failed for ${SERVER_DOCKER}/api/v1/sum (expected HTTP 200)." >&2
    echo "Another process may be bound to the host port; use docker compose for fuzzing." >&2
    exit 1
  fi
}

ensure_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "Docker is required. Install Docker and ensure the daemon is running." >&2
    exit 1
  fi
}

validate_report_format() {
  case "${CATS_REPORT_FORMAT}" in
    HTML_JS|HTML_ONLY|JUNIT) ;;
    *)
      echo "Invalid CATS_REPORT_FORMAT: ${CATS_REPORT_FORMAT}" >&2
      echo "Supported: HTML_JS, HTML_ONLY, JUNIT" >&2
      exit 2
      ;;
  esac
}

ensure_cats_image() {
  if [[ "${CATS_REBUILD}" == "1" ]] || ! docker image inspect "${CATS_IMAGE}" >/dev/null 2>&1; then
    echo "Building CATS image ${CATS_IMAGE} from ${CATS_DIR}/Dockerfile..."
    docker build \
      --build-arg "CATS_VERSION=${CATS_VERSION}" \
      -t "${CATS_IMAGE}" \
      -f "${CATS_DIR}/Dockerfile" \
      "${CATS_DIR}"
  fi
}

run_cats_docker() {
  local -a docker_args=(run --rm -v "${REPO_ROOT}:/workspace" -w /workspace)
  if [[ -n "${CATS_DOCKER_NETWORK}" ]]; then
    docker_args+=(--network "${CATS_DOCKER_NETWORK}")
  else
    docker_args+=(--add-host=host.docker.internal:host-gateway)
  fi
  docker "${docker_args[@]}" "${CATS_IMAGE}" "$@"
}

wait_for_server() {
  local elapsed=0
  echo "Waiting for ${HEALTH_URL} (timeout ${WAIT_TIMEOUT_SEC}s)..."
  until curl -fsS "${HEALTH_URL}" >/dev/null 2>&1; do
    if (( elapsed >= WAIT_TIMEOUT_SEC )); then
      echo "API not reachable at ${HEALTH_URL}. Start it first, for example:" >&2
      echo "  docker compose up --build" >&2
      echo "  cd service && ./mvnw spring-boot:run" >&2
      exit 1
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done
  echo "API is up."
}

common_cats_args() {
  COMMON_ARGS=(
    --contract="${CONTRACT_CONTAINER}"
    --server="${SERVER_DOCKER}"
    --reportFormat="${CATS_REPORT_FORMAT}"
    --output="${REPORT_CONTAINER}"
    -H "Content-Type=application/json"
    -H "Accept=application/json"
  )
  if [[ -n "${CATS_SEED}" ]]; then
    COMMON_ARGS+=(--seed="${CATS_SEED}")
  fi
}

list_contract_paths() {
  run_cats_docker list paths -c "${CONTRACT_CONTAINER}" 2>/dev/null \
    | grep -E '^ ◼ ' \
    | sed -E 's/^ ◼ ([^:]+):.*/\1/'
}

run_cats_fuzzers() {
  local -a args=("${COMMON_ARGS[@]}")

  case "${CATS_MODE}" in
    blackbox)
      args+=(--blackbox --skipReportingForIgnored)
      ;;
    openapi)
      args+=(
        --httpMethods=POST
        --ignoreResponseBodyCheck
        --skipFuzzers=CheckSecurityHeaders,DuplicateHeaders
      )
      ;;
    *)
      echo "Unknown CATS_MODE: ${CATS_MODE} (use blackbox, openapi, or random)" >&2
      exit 2
      ;;
  esac

  echo "Running CATS fuzzers (${CATS_MODE}) in Docker"
  echo "Image:    ${CATS_IMAGE}"
  echo "Server:   ${SERVER_DOCKER} (host: ${SERVER})"
  echo "Contract: ${CONTRACT_CONTAINER}"
  echo "Report:   ${REPORT_CONTAINER} (${CATS_REPORT_FORMAT})"
  run_cats_docker "${args[@]}"
}

run_cats_random_path() {
  local path="$1"
  local -a args=(
    random
    "${COMMON_ARGS[@]}"
    -X POST
    -p "${path}"
    --mc "${CATS_RANDOM_MATCH_CODES}"
  )

  if [[ -n "${CATS_RANDOM_MUTATIONS}" ]]; then
    args+=(--stopAfterMutations="${CATS_RANDOM_MUTATIONS}")
  else
    args+=(--stopAfterTimeInSec="${CATS_RANDOM_SECONDS}")
  fi

  echo "Running CATS random on ${path} (match HTTP ${CATS_RANDOM_MATCH_CODES})"
  run_cats_docker "${args[@]}"
}

run_cats_random() {
  local -a paths=()
  local path_line

  if [[ -n "${CATS_RANDOM_PATH}" ]]; then
    paths=("${CATS_RANDOM_PATH}")
  else
    while IFS= read -r path_line; do
      [[ -n "${path_line}" ]] && paths+=("${path_line}")
    done < <(list_contract_paths)
  fi

  if ((${#paths[@]} == 0)); then
    echo "No paths found in contract: ${CONTRACT}" >&2
    exit 1
  fi

  echo "Running CATS random (${CATS_MODE}) in Docker"
  echo "Image:    ${CATS_IMAGE}"
  echo "Server:   ${SERVER_DOCKER} (host: ${SERVER})"
  echo "Contract: ${CONTRACT_CONTAINER}"
  echo "Report:   ${REPORT_CONTAINER} (${CATS_REPORT_FORMAT})"
  echo "Paths:    ${paths[*]}"

  local path
  for path in "${paths[@]}"; do
    run_cats_random_path "${path}"
  done
}

run_cats() {
  common_cats_args
  case "${CATS_MODE}" in
    blackbox|openapi)
      run_cats_fuzzers
      ;;
    random)
      run_cats_random
      ;;
    *)
      echo "Unknown CATS_MODE: ${CATS_MODE} (use blackbox, openapi, or random)" >&2
      exit 2
      ;;
  esac
}

if [[ "${RUN_REPORT_SERVER}" == "1" ]]; then
  run_report_server
fi

[[ -f "${CATS_DIR}/Dockerfile" ]] || {
  echo "CATS Dockerfile not found: ${CATS_DIR}/Dockerfile" >&2
  exit 1
}

CONTRACT="$(cd "$(dirname "${CONTRACT}")" && pwd)/$(basename "${CONTRACT}")"
[[ -f "${CONTRACT}" ]] || {
  echo "OpenAPI contract not found: ${CONTRACT}" >&2
  exit 1
}

ensure_report_dir_for_fuzz
CONTRACT_CONTAINER="$(to_workspace_path "${CONTRACT}")"
REPORT_CONTAINER="$(to_workspace_path "${REPORT_DIR}")"
resolve_server_for_docker

validate_report_format
ensure_docker
ensure_cats_image
wait_for_server
server_port_from_url() {
  local hostport="${1#*://}"
  hostport="${hostport%%/*}"
  local port="${hostport##*:}"
  [[ "${port}" == "${hostport}" ]] && port="8080"
  echo "${port}"
}
warn_host_port_conflict "$(server_port_from_url "${SERVER}")"
verify_cats_reachability
run_cats
