#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=skills/smartagent-lab/scripts/common.sh
source "$SCRIPT_DIR/common.sh"

usage() {
  cat <<'EOF'
Usage:
  prepare_remote_push.sh --profile <path> [--execute]

Behavior:
  - Dry-run by default
  - Connects through the control host to each managed host
  - Makes the Smart Agent install root and staging directory writable by the managed SSH user
  - Leaves the Smart Agent runtime user/group unchanged
EOF
}

PROFILE=""
EXECUTE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      PROFILE="${2:-}"
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

note "Managed SSH user: $MANAGED_SSH_USER"

if [[ "$EXECUTE" -eq 0 ]]; then
  note
  note "Dry run only. Planned managed-host commands:"
  cat <<EOF
sudo mkdir -p /opt/appdynamics/appdsmartagent/staging
sudo chgrp "$MANAGED_SSH_USER" /opt/appdynamics/appdsmartagent /opt/appdynamics/appdsmartagent/staging
sudo chmod 775 /opt/appdynamics/appdsmartagent /opt/appdynamics/appdsmartagent/staging
stat -c "%U %G %a %n" /opt/appdynamics/appdsmartagent /opt/appdynamics/appdsmartagent/staging
EOF
  exit 0
fi

note "== Prepare Remote Push Directories =="
for host in "${MANAGED_HOSTS[@]}"; do
  note "-- $host --"
  managed_via_control "$host" "$(cat <<EOF
set -euo pipefail

sudo mkdir -p /opt/appdynamics/appdsmartagent/staging
sudo chgrp "$MANAGED_SSH_USER" /opt/appdynamics/appdsmartagent /opt/appdynamics/appdsmartagent/staging
sudo chmod 775 /opt/appdynamics/appdsmartagent /opt/appdynamics/appdsmartagent/staging
stat -c "%U %G %a %n" /opt/appdynamics/appdsmartagent /opt/appdynamics/appdsmartagent/staging
EOF
)"
  note
done
