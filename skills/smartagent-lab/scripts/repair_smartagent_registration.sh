#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=skills/smartagent-lab/scripts/common.sh
source "$SCRIPT_DIR/common.sh"

PROFILE=""
TARGET_HOST=""
EXECUTE=0

usage() {
  cat <<'EOF'
Usage:
  repair_smartagent_registration.sh --profile <path> --host <managed-private-ip> [--execute]

Behavior:
  - Dry-run by default
  - Connects through the control host to one managed host
  - Backs up local Smart Agent runtime state under the managed user's home
  - Removes only id, store.json, and log.log from /opt/appdynamics/appdsmartagent
  - Restarts Smart Agent locally with auto-attach enabled; it does not use --remote
  - Restores remote-push directory permissions for the managed SSH user
  - Fails if the restarted Smart Agent does not connect to the controller
EOF
}

host_is_managed_target() {
  local candidate="$1"
  local managed_host
  for managed_host in "${MANAGED_HOSTS[@]}"; do
    [[ "$managed_host" == "$candidate" ]] && return 0
  done
  return 1
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --profile)
        PROFILE="${2:-}"
        shift 2
        ;;
      --host)
        TARGET_HOST="${2:-}"
        shift 2
        ;;
      --execute)
        EXECUTE=1
        shift
        ;;
      -h|--help)
        usage
        return 0
        ;;
      *)
        usage >&2
        die "Unknown argument: $1"
        ;;
    esac
  done

  [[ -n "$PROFILE" ]] || die "--profile is required"
  [[ -n "$TARGET_HOST" ]] || die "--host is required"
  load_profile "$PROFILE"
  host_is_managed_target "$TARGET_HOST" || die "--host must match an entry in managed_hosts"

  local repair_script
  repair_script="$(cat <<EOF
set -euo pipefail

backup_dir="\${HOME}/smartagent-state-backup-\$(date -u +%Y%m%dT%H%M%SZ)"
echo "backup_dir=\$backup_dir"
sudo mkdir -p "\$backup_dir"

sudo systemctl stop smartagent || true
for file_name in id store.json log.log; do
  source_path="/opt/appdynamics/appdsmartagent/\$file_name"
  if sudo test -e "\$source_path"; then
    sudo cp -a "\$source_path" "\$backup_dir/"
    sudo rm -f "\$source_path"
  fi
done

sudo systemctl daemon-reload || true
cd /opt/appdynamics/appdsmartagent
sudo ./smartagentctl start --service --enable-auto-attach
sleep 15

new_id="\$(sudo cat /opt/appdynamics/appdsmartagent/id 2>/dev/null || true)"
echo "smartagent_id=\$new_id"
if [[ "\$new_id" =~ ^[0-9A-HJKMNP-TV-Z]{26}$ ]]; then
  echo "smartagent_id_format_ok=yes"
else
  echo "smartagent_id_format_ok=no"
fi

smartagent_start="\$(systemctl show -p ExecMainStartTimestamp --value smartagent 2>/dev/null || true)"
connected_count=0
if [[ -n "\$smartagent_start" ]]; then
  connected_count="\$(sudo journalctl -u smartagent --since "\$smartagent_start" --no-pager 2>/dev/null | grep -F '"msg":"Connected to server"' | wc -l | tr -d '[:space:]' || true)"
fi
echo "smartagent_connected_since_start_count=\$connected_count"
if [[ "\$connected_count" =~ ^[0-9]+$ && "\$connected_count" -gt 0 ]]; then
  echo "smartagent_connected_since_start=yes"
else
  echo "smartagent_connected_since_start=no"
fi

sudo mkdir -p /opt/appdynamics/appdsmartagent/staging
sudo chgrp "$MANAGED_SSH_USER" /opt/appdynamics/appdsmartagent /opt/appdynamics/appdsmartagent/staging
sudo chmod 775 /opt/appdynamics/appdsmartagent /opt/appdynamics/appdsmartagent/staging
stat -c "%U %G %a %n" /opt/appdynamics/appdsmartagent /opt/appdynamics/appdsmartagent/staging
EOF
)"

  if [[ "$EXECUTE" -eq 0 ]]; then
    note "Dry run only. Planned registration repair for $TARGET_HOST:"
    printf '%s\n' "$repair_script"
    note
    note "Run with --execute to apply."
    return 0
  fi

  local output
  if ! output="$(managed_via_control "$TARGET_HOST" "$repair_script")"; then
    printf '%s\n' "$output"
    die "registration repair failed on $TARGET_HOST"
  fi
  printf '%s\n' "$output"
  grep -Fqx "smartagent_id_format_ok=yes" <<< "$output" || die "Smart Agent did not create a valid ID on $TARGET_HOST"
  grep -Fqx "smartagent_connected_since_start=yes" <<< "$output" || die "Smart Agent did not connect to the controller after repair on $TARGET_HOST"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
