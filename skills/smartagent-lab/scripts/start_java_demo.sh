#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=skills/smartagent-lab/scripts/common.sh
source "$SCRIPT_DIR/common.sh"

usage() {
  cat <<'EOF'
Usage:
  start_java_demo.sh --profile <path> [--host <private-ip>] [--execute]

Behavior:
  - Dry-run by default
  - Runs through the control host to a private-IP Java demo target
  - Starts spring-petclinic only when --execute is provided
EOF
}

PROFILE=""
HOST_OVERRIDE=""
EXECUTE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      PROFILE="${2:-}"
      shift 2
      ;;
    --host)
      HOST_OVERRIDE="${2:-}"
      shift 2
      ;;
    --execute)
      EXECUTE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown argument: $1"
      ;;
  esac
done

[[ -n "$PROFILE" ]] || die "--profile is required"
load_profile "$PROFILE"

JAVA_HOST="${HOST_OVERRIDE:-$JAVA_DEMO_HOST}"
[[ -n "$JAVA_HOST" ]] || die "No Java demo host is configured"
[[ -n "${JAVA_DEMO_DIR:-}" ]] || die "java_demo_dir is required in the profile"

note "Java host: $JAVA_HOST"
note "Java demo dir: $JAVA_DEMO_DIR"

if [[ "$EXECUTE" -eq 0 ]]; then
  note
  note "Dry run only. Planned remote commands:"
  cat <<EOF
cd $JAVA_DEMO_DIR
nohup ./run-app.sh >/tmp/petclinic.log 2>&1 < /dev/null &
sleep 8
ss -ltnp | grep 8080
curl -sfI http://127.0.0.1:8080
tail -n 20 /tmp/petclinic.log
EOF
  exit 0
fi

JAVA_SCRIPT="$(cat <<EOF
set -euo pipefail

if curl -sfI http://127.0.0.1:8080 >/dev/null 2>&1; then
  echo "Java demo already healthy on port 8080"
  ss -ltnp | grep 8080 || true
  curl -sfI http://127.0.0.1:8080 | sed -n '1,5p'
  exit 0
fi

cd "$JAVA_DEMO_DIR"
nohup ./run-app.sh >/tmp/petclinic.log 2>&1 < /dev/null &
sleep 8
ss -ltnp | grep 8080
curl -sfI http://127.0.0.1:8080 | sed -n '1,5p'
echo "---"
tail -n 20 /tmp/petclinic.log
EOF
)"

managed_via_control "$JAVA_HOST" "$JAVA_SCRIPT"
