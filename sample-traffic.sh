#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8080}"

usage() {
  cat <<EOF
Generate sample traffic for the Calculator API.

Usage: $(basename "$0") <ok|ko>

  ok   POST /api/v1/sum  — successful request (1 + 2)
  ko   POST /api/v1/div  — division by zero (1 / 0)

Environment:
  BASE_URL   API base URL (default: http://localhost:8080)
EOF
}

case "${1:-}" in
  ok)
    curl -sS -w "\nHTTP %{http_code}\n" -X POST "${BASE_URL}/api/v1/sum" \
      -H 'Content-Type: application/json' \
      -d '{"operator1": 1, "operator2": 2}'
    ;;
  ko)
    curl -sS -w "\nHTTP %{http_code}\n" -X POST "${BASE_URL}/api/v1/div" \
      -H 'Content-Type: application/json' \
      -d '{"operator1": 1, "operator2": 0}'
    ;;
  -h|--help|help|"")
    usage
    exit "${1:+0}"
    ;;
  *)
    echo "Unknown option: $1" >&2
    usage >&2
    exit 1
    ;;
esac
