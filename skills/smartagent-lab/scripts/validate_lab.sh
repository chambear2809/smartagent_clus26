#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=skills/smartagent-lab/scripts/common.sh
source "$SCRIPT_DIR/common.sh"

PROFILE=""
VALIDATION_FAILURES=0
REQUIRE_JAVA_COLLECTOR=0

usage() {
  cat <<'EOF'
Usage:
  validate_lab.sh --profile <path> [--require-java-collector]

Behavior:
  - Runs read-only validation
  - Connects to the public control host
  - Uses the control host to reach managed hosts by private IP
  - Fails with a non-zero exit code when critical demo prerequisites drift
  - Keeps appendix-only checks visible without making them fatal
  - When --require-java-collector is set, fails if the Java demo host is not listening on 4317 or 4318
EOF
}

section_has_line() {
  local output="$1"
  local expected="$2"
  grep -Fqx "$expected" <<< "$output"
}

record_failure() {
  local message="$1"
  note "VALIDATION ERROR: $message"
  VALIDATION_FAILURES=$((VALIDATION_FAILURES + 1))
}

require_marker() {
  local output="$1"
  local marker="$2"
  local message="$3"
  if ! section_has_line "$output" "$marker"; then
    record_failure "$message"
  fi
}

validate_control_host() {
  local output
  local control_script

  note "== Control Host =="
  control_script="$(cat <<EOF
set -euo pipefail
unset LD_PRELOAD || true

hostname
echo "bundle_dir=$CONTROL_BUNDLE_DIR"
if [[ -d "$CONTROL_BUNDLE_DIR" ]]; then
  echo "bundle_dir_exists=yes"
else
  echo "bundle_dir_exists=no"
fi
if [[ -x "$CONTROL_BUNDLE_DIR/smartagentctl" ]]; then
  echo "bundle_cli_exists=yes"
  "$CONTROL_BUNDLE_DIR/smartagentctl" --version || true
else
  echo "bundle_cli_exists=no"
fi
control_state="\$(systemctl is-active smartagent 2>/dev/null || true)"
echo "control_smartagent_state=\$control_state"
if [[ "\$control_state" == "active" ]]; then
  echo "control_smartagent_active=yes"
else
  echo "control_smartagent_active=no"
fi
echo "control_service_user=\$(systemctl show -p User --value smartagent 2>/dev/null || true)"
echo "control_service_group=\$(systemctl show -p Group --value smartagent 2>/dev/null || true)"
echo "---"
preload_hits="\$(sudo grep -RIn 'LD_PRELOAD\\|appdcli/lib/libpreload.so' /etc/environment /etc/profile.d 2>/dev/null | sed -n '1,20p' || true)"
if [[ -n "\$preload_hits" ]]; then
  echo "ld_preload_reference_present=yes"
  printf '%s\n' "\$preload_hits"
else
  echo "ld_preload_reference_present=no"
fi
echo "---"
if [[ -f "$CONTROL_BUNDLE_DIR/remote.yaml" ]]; then
  echo "remote_yaml_exists=yes"
  grep -nE 'username:|privileged:|user:|group:' "$CONTROL_BUNDLE_DIR/remote.yaml" | sed -n '1,40p' || true
  if grep -Eq "^[[:space:]]*username:[[:space:]]*$EXPECTED_REMOTE_AUTH_USERNAME([[:space:]#]|$)" "$CONTROL_BUNDLE_DIR/remote.yaml"; then
    echo "remote_auth_username_ok=yes"
  else
    echo "remote_auth_username_ok=no"
  fi
  if grep -Eq "^[[:space:]]*privileged:[[:space:]]*$EXPECTED_REMOTE_PRIVILEGED([[:space:]#]|$)" "$CONTROL_BUNDLE_DIR/remote.yaml"; then
    echo "remote_privileged_ok=yes"
  else
    echo "remote_privileged_ok=no"
  fi
  awk -v expect_user="$EXPECTED_SMARTAGENT_USER" -v expect_group="$EXPECTED_SMARTAGENT_GROUP" '
    function normalize(value) {
      sq = sprintf("%c", 39)
      gsub(/#.*/, "", value)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      gsub(/^"/, "", value)
      gsub(/"$/, "", value)
      gsub("^" sq, "", value)
      gsub(sq "$", "", value)
      return value
    }
    /^[[:space:]]*hosts:[[:space:]]*$/ { in_hosts=1; next }
    in_hosts && /^[^[:space:]]/ { in_hosts=0 }
    in_hosts && /^[[:space:]]*-[[:space:]]*host:/ {
      if (seen_host && (!user_ok || !group_ok)) fail=1
      seen_host=1
      host_count++
      user_ok=0
      group_ok=0
      next
    }
    in_hosts && /^[[:space:]]*user:[[:space:]]*/ {
      value=\$0
      sub(/^[[:space:]]*user:[[:space:]]*/, "", value)
      value=normalize(value)
      if (value == expect_user) user_ok=1
      next
    }
    in_hosts && /^[[:space:]]*group:[[:space:]]*/ {
      value=\$0
      sub(/^[[:space:]]*group:[[:space:]]*/, "", value)
      value=normalize(value)
      if (value == expect_group) group_ok=1
      next
    }
    END {
      if (seen_host && (!user_ok || !group_ok)) fail=1
      if (host_count == 0) {
        print "remote_runtime_identity_ok=no"
        print "remote_host_count=0"
      } else if (fail) {
        print "remote_runtime_identity_ok=no"
        print "remote_host_count=" host_count
      } else {
        print "remote_runtime_identity_ok=yes"
        print "remote_host_count=" host_count
      }
    }
  ' "$CONTROL_BUNDLE_DIR/remote.yaml"
else
  echo "remote_yaml_exists=no"
fi
echo "---"
find "\$(dirname "$CONTROL_BUNDLE_DIR")" -maxdepth 1 -type d -name '$(basename "$CONTROL_BUNDLE_DIR")*' | sort
EOF
)"

  if ! output="$(control_ssh_stream "$control_script")"; then
    record_failure "unable to validate control host ${CONTROL_SSH_USER}@${CONTROL_HOST}"
    note
    return
  fi

  printf '%s\n' "$output"
  require_marker "$output" "bundle_dir_exists=yes" "control bundle directory is missing: $CONTROL_BUNDLE_DIR"
  require_marker "$output" "bundle_cli_exists=yes" "smartagentctl is missing from the control bundle: $CONTROL_BUNDLE_DIR"
  require_marker "$output" "control_smartagent_active=yes" "control-host smartagent.service is not active"
  require_marker "$output" "remote_yaml_exists=yes" "remote.yaml is missing from the control bundle"
  require_marker "$output" "remote_auth_username_ok=yes" "remote.yaml SSH username does not match the expected value"
  require_marker "$output" "remote_privileged_ok=yes" "remote.yaml privileged setting does not match the expected value"
  require_marker "$output" "remote_runtime_identity_ok=yes" "remote.yaml managed-host Smart Agent user/group does not match the expected value"
  note
}

validate_managed_hosts() {
  local host output managed_script

  note "== Managed Smart Agent Hosts =="
  for host in "${MANAGED_HOSTS[@]}"; do
    note "-- $host --"
    managed_script="$(cat <<EOF
set -euo pipefail

hostname
smartagent_state="\$(systemctl is-active smartagent 2>/dev/null || true)"
echo "smartagent_active_state=\$smartagent_state"
if [[ "\$smartagent_state" == "active" ]]; then
  echo "smartagent_active=yes"
else
  echo "smartagent_active=no"
fi
if [[ -x /opt/appdynamics/appdsmartagent/smartagentctl ]]; then
  echo "smartagent_cli_exists=yes"
  /opt/appdynamics/appdsmartagent/smartagentctl --version || true
else
  echo "smartagent_cli_exists=no"
fi
service_user="\$(sudo systemctl show -p User --value smartagent 2>/dev/null || true)"
service_group="\$(sudo systemctl show -p Group --value smartagent 2>/dev/null || true)"
process_identity="\$(ps -o user=,group= -C smartagent | sed -n '1p' || true)"
if [[ -z "\$service_user" && -n "\$process_identity" ]]; then
  service_user="\$(printf '%s\n' "\$process_identity" | awk '{print \$1}')"
fi
if [[ -z "\$service_group" && -n "\$process_identity" ]]; then
  service_group="\$(printf '%s\n' "\$process_identity" | awk '{print \$2}')"
fi
echo "smartagent_service_user=\$service_user"
echo "smartagent_service_group=\$service_group"
if [[ "\$service_user" == "$EXPECTED_SMARTAGENT_USER" && "\$service_group" == "$EXPECTED_SMARTAGENT_GROUP" ]]; then
  echo "smartagent_service_identity_ok=yes"
else
  echo "smartagent_service_identity_ok=no"
fi
if [[ -s /opt/appdynamics/appdsmartagent/config.ini ]]; then
  echo "smartagent_config_nonempty=yes"
else
  echo "smartagent_config_nonempty=no"
fi
if test -w /opt/appdynamics/appdsmartagent; then
  echo "smartagent_remote_push_root_writable=yes"
else
  echo "smartagent_remote_push_root_writable=no"
fi
if test -w /opt/appdynamics/appdsmartagent/staging; then
  echo "smartagent_remote_push_staging_writable=yes"
else
  echo "smartagent_remote_push_staging_writable=no"
fi
ps -o user=,group=,comm= -C smartagent | sed -n '1,3p' || true
EOF
)"

    if ! output="$(managed_via_control "$host" "$managed_script")"; then
      record_failure "unable to validate managed host $host from the control node"
      note
      continue
    fi

    printf '%s\n' "$output"
    require_marker "$output" "smartagent_active=yes" "managed host $host does not have an active smartagent.service"
    require_marker "$output" "smartagent_cli_exists=yes" "managed host $host is missing /opt/appdynamics/appdsmartagent/smartagentctl"
    require_marker "$output" "smartagent_service_identity_ok=yes" "managed host $host is not running Smart Agent as ${EXPECTED_SMARTAGENT_USER}:${EXPECTED_SMARTAGENT_GROUP}"
    require_marker "$output" "smartagent_config_nonempty=yes" "managed host $host has an empty /opt/appdynamics/appdsmartagent/config.ini"
    require_marker "$output" "smartagent_remote_push_root_writable=yes" "managed host $host does not let ${MANAGED_SSH_USER} write /opt/appdynamics/appdsmartagent for remote push"
    require_marker "$output" "smartagent_remote_push_staging_writable=yes" "managed host $host does not let ${MANAGED_SSH_USER} write /opt/appdynamics/appdsmartagent/staging for remote push"
    note
  done
}

validate_java_demo() {
  local output java_script

  [[ -n "${JAVA_DEMO_HOST:-}" && -n "${JAVA_DEMO_DIR:-}" ]] || return 0

  note "== Java Demo Host =="
  java_script="$(cat <<EOF
set -euo pipefail

hostname
if [[ -d "$JAVA_DEMO_DIR" ]]; then
  echo "java_demo_dir_exists=yes"
else
  echo "java_demo_dir_exists=no"
fi
if [[ -x "$JAVA_DEMO_DIR/run-app.sh" ]]; then
  echo "run_app_exists=yes"
else
  echo "run_app_exists=no"
fi
java_http_status="\$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8080 || true)"
echo "java_demo_http_status=\$java_http_status"
if [[ "\$java_http_status" == "200" ]]; then
  echo "java_demo_http_ok=yes"
else
  echo "java_demo_http_ok=no"
fi
ss -ltnp | grep 8080 || true
curl -sfI http://127.0.0.1:8080 | sed -n '1,5p' || true
collector_ports="\$(ss -ltnp | egrep '(:4317|:4318)' || true)"
if [[ -n "\$collector_ports" ]]; then
  echo "java_collector_listener=yes"
  printf '%s\n' "\$collector_ports"
else
  echo "java_collector_listener=no"
fi
collector_service_state="\$(systemctl is-active splunk-otel-collector 2>/dev/null || true)"
echo "java_collector_service_state=\$collector_service_state"
if [[ "\$collector_service_state" == "active" ]]; then
  echo "java_collector_service_active=yes"
else
  echo "java_collector_service_active=no"
fi
if curl -fsS http://127.0.0.1:13133/ >/dev/null 2>&1; then
  echo "java_collector_health_ok=yes"
else
  echo "java_collector_health_ok=no"
fi
collector_recent_errors="\$(sudo journalctl -u splunk-otel-collector --since '-3 min' --no-pager 2>/dev/null | grep -E 'Exporting failed|authentication failed|Permanent error|failed to push|context deadline exceeded' | tail -n 20 || true)"
if [[ -n "\$collector_recent_errors" ]]; then
  echo "java_collector_recent_errors=no"
  printf '%s\n' "\$collector_recent_errors"
else
  echo "java_collector_recent_errors=yes"
fi
pgrep -af 'otelcol|appdotelcol_' | sed -n '1,8p' || true
EOF
)"

  if ! output="$(managed_via_control "$JAVA_DEMO_HOST" "$java_script")"; then
    record_failure "unable to validate Java demo host $JAVA_DEMO_HOST"
    note
    return
  fi

  printf '%s\n' "$output"
  require_marker "$output" "java_demo_dir_exists=yes" "Java demo directory is missing: $JAVA_DEMO_DIR"
  require_marker "$output" "run_app_exists=yes" "Java demo start script is missing: $JAVA_DEMO_DIR/run-app.sh"
  if [[ "$REQUIRE_JAVA_COLLECTOR" -eq 1 ]]; then
    require_marker "$output" "java_collector_listener=yes" "Java demo host $JAVA_DEMO_HOST does not have a local collector listening on 4317 or 4318"
    require_marker "$output" "java_collector_service_active=yes" "Java demo host $JAVA_DEMO_HOST does not have an active splunk-otel-collector service"
    require_marker "$output" "java_collector_health_ok=yes" "Java demo host $JAVA_DEMO_HOST did not pass the collector health check on 127.0.0.1:13133"
    require_marker "$output" "java_collector_recent_errors=yes" "Java demo host $JAVA_DEMO_HOST has recent collector export errors"
  elif ! section_has_line "$output" "java_collector_listener=yes"; then
    note "VALIDATION WARNING: Java demo host $JAVA_DEMO_HOST does not have a local collector listening on 4317 or 4318"
  elif ! section_has_line "$output" "java_collector_service_active=yes"; then
    note "VALIDATION WARNING: Java demo host $JAVA_DEMO_HOST has collector listeners but the splunk-otel-collector service is not active"
  elif ! section_has_line "$output" "java_collector_health_ok=yes"; then
    note "VALIDATION WARNING: Java demo host $JAVA_DEMO_HOST did not pass the collector health check on 127.0.0.1:13133"
  elif ! section_has_line "$output" "java_collector_recent_errors=yes"; then
    note "VALIDATION WARNING: Java demo host $JAVA_DEMO_HOST has recent collector export errors"
  fi
  note
}

validate_node_demo() {
  local output node_script

  [[ -n "${NODE_DEMO_HOST:-}" ]] || return 0

  note "== Node Demo Host =="
  node_script="$(cat <<'EOF'
set -euo pipefail

hostname
if command -v node >/dev/null 2>&1; then
  echo "node_runtime_present=yes"
  command -v node
  node -v 2>/dev/null || true
else
  echo "node_runtime_present=no"
fi
EOF
)"

  if ! output="$(managed_via_control "$NODE_DEMO_HOST" "$node_script")"; then
    record_failure "unable to validate Node demo host $NODE_DEMO_HOST"
    note
    return
  fi

  printf '%s\n' "$output"
  require_marker "$output" "node_runtime_present=yes" "Node.js runtime is not present on $NODE_DEMO_HOST"
  note
}

validate_infra_host() {
  local output infra_script

  [[ -n "${INFRA_HOST:-}" ]] || return 0

  note "== Infra Host =="
  infra_script="$(cat <<'EOF'
set -euo pipefail

hostname
machine_agent_state="$(systemctl is-active appdynamics-machine-agent 2>/dev/null || true)"
echo "machine_agent_active_state=$machine_agent_state"
if [[ "$machine_agent_state" == "active" ]]; then
  echo "machine_agent_active=yes"
else
  echo "machine_agent_active=no"
fi
smartagent_state="$(systemctl is-active smartagent 2>/dev/null || true)"
echo "smartagent_active_state=$smartagent_state"
systemctl status appdynamics-machine-agent --no-pager -l | sed -n '1,25p' || true
EOF
)"

  if ! output="$(managed_via_control "$INFRA_HOST" "$infra_script")"; then
    note "VALIDATION WARNING: unable to validate appendix infra host $INFRA_HOST"
    note
    return
  fi

  printf '%s\n' "$output"
  if ! section_has_line "$output" "machine_agent_active=yes"; then
    note "VALIDATION WARNING: appendix infra host $INFRA_HOST does not have an active Machine Agent"
  fi
  note
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --profile)
        PROFILE="${2:-}"
        shift 2
        ;;
      --require-java-collector)
        REQUIRE_JAVA_COLLECTOR=1
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

  VALIDATION_FAILURES=0
  validate_control_host
  validate_managed_hosts
  validate_java_demo
  validate_node_demo
  validate_infra_host

  if [[ "$VALIDATION_FAILURES" -gt 0 ]]; then
    note "Validation failed with $VALIDATION_FAILURES critical issue(s)."
    exit 1
  fi

  note "Validation passed with no critical issues."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
