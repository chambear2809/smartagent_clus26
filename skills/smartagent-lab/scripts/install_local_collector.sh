#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=skills/smartagent-lab/scripts/common.sh
source "$SCRIPT_DIR/common.sh"

usage() {
  cat <<'EOF'
Usage:
  install_local_collector.sh --profile <path> [--archive <tar.gz> | --use-splunk-installer] [--host <private-ip>] [--install-dir <path>] [--execute]

Behavior:
  - Dry-run by default
  - Either copies a collector archive through the control host, or installs the collector directly from Splunk's Linux installer
  - Creates a local collector config that forwards OTLP traces and metrics to Splunk Observability Cloud
  - Starts the collector on the managed host and checks for listeners on 4317 or 4318
  - `--install-dir` applies only to the archive workflow; the installer workflow uses package defaults under /etc and /usr

Requirements:
  - Export SPLUNK_REALM and SPLUNK_ACCESS_TOKEN before running with --execute
EOF
}

PROFILE=""
ARCHIVE=""
HOST_OVERRIDE=""
INSTALL_DIR=""
INSTALL_DIR_SET=0
USE_SPLUNK_INSTALLER=0
EXECUTE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      PROFILE="${2:-}"
      shift 2
      ;;
    --archive)
      ARCHIVE="${2:-}"
      shift 2
      ;;
    --use-splunk-installer)
      USE_SPLUNK_INSTALLER=1
      shift
      ;;
    --host)
      HOST_OVERRIDE="${2:-}"
      shift 2
      ;;
    --install-dir)
      INSTALL_DIR="${2:-}"
      INSTALL_DIR_SET=1
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

if [[ "$USE_SPLUNK_INSTALLER" -eq 0 ]]; then
  [[ -n "$ARCHIVE" ]] || die "either --archive or --use-splunk-installer is required"
  [[ -f "$ARCHIVE" ]] || die "Collector archive not found: $ARCHIVE"
elif [[ -n "$ARCHIVE" ]]; then
  die "use either --archive or --use-splunk-installer, not both"
fi

if [[ "$USE_SPLUNK_INSTALLER" -eq 1 && "$INSTALL_DIR_SET" -eq 1 ]]; then
  die "--install-dir is only supported with --archive"
fi

COLLECTOR_HOST="${HOST_OVERRIDE:-$JAVA_DEMO_HOST}"
[[ -n "$COLLECTOR_HOST" ]] || die "No collector host was provided and java_demo_host is empty in the profile"

INSTALL_DIR="${INSTALL_DIR:-/home/${MANAGED_SSH_USER}/appdotelcol-demo}"
ARCHIVE_NAME=""
REMOTE_ARCHIVE_PATH=""
if [[ -n "$ARCHIVE" ]]; then
  ARCHIVE_NAME="$(basename "$ARCHIVE")"
  REMOTE_ARCHIVE_PATH="/home/${MANAGED_SSH_USER}/${ARCHIVE_NAME}"
fi

note "Lab: ${LAB_NAME:-unknown}"
note "Control host: $CONTROL_HOST"
note "Collector host: $COLLECTOR_HOST"
if [[ "$USE_SPLUNK_INSTALLER" -eq 1 ]]; then
  note "Collector source: official Splunk Linux installer"
else
  note "Collector archive: $ARCHIVE"
fi
if [[ "$USE_SPLUNK_INSTALLER" -eq 1 ]]; then
  note "Install dir: package defaults (/usr/bin and /etc/otel/collector)"
else
  note "Install dir: $INSTALL_DIR"
fi

if [[ "$EXECUTE" -eq 0 ]]; then
  note
  note "Dry run only. Planned steps:"
  if [[ "$USE_SPLUNK_INSTALLER" -eq 1 ]]; then
    note "1. Reuse the existing splunk-otel-collector package if present, otherwise download Splunk's Linux collector installer on $COLLECTOR_HOST."
    note "2. Ensure collector-only mode with realm/token and no auto-instrumentation."
    note "3. Write a minimal local-collector config for OTel -> O11y forwarding."
    note "4. Restart the service and verify health, listeners, and recent journal state."
  else
    note "1. Copy $ARCHIVE_NAME to the control host home directory."
    note "2. Copy $ARCHIVE_NAME from the control host to $COLLECTOR_HOST:$REMOTE_ARCHIVE_PATH."
    note "3. Unpack into $INSTALL_DIR on $COLLECTOR_HOST."
    note "4. Write otel-config.yaml with Splunk OTLP/HTTP trace and metric export."
    note "5. Start ./appdotelcol_* --config otel-config.yaml and verify health, listeners, and recent log state."
  fi
  note
  note "Next step:"
  if [[ "$USE_SPLUNK_INSTALLER" -eq 1 ]]; then
    note "  $0 --profile $PROFILE --use-splunk-installer --execute"
  else
    note "  $0 --profile $PROFILE --archive $ARCHIVE --execute"
  fi
  exit 0
fi

[[ -n "${SPLUNK_REALM:-}" ]] || die "SPLUNK_REALM must be exported before --execute"
[[ -n "${SPLUNK_ACCESS_TOKEN:-}" ]] || die "SPLUNK_ACCESS_TOKEN must be exported before --execute"

if [[ "$USE_SPLUNK_INSTALLER" -eq 0 ]]; then
  note "Uploading collector archive to control host..."
  control_scp_to_home "$ARCHIVE" "$ARCHIVE_NAME"

  note "Copying collector archive from control host to managed host..."
  managed_copy_via_control "$COLLECTOR_HOST" "/home/${CONTROL_SSH_USER}/${ARCHIVE_NAME}" "$REMOTE_ARCHIVE_PATH"
fi

REMOTE_SCRIPT="$(cat <<EOF
set -euo pipefail

INSTALL_DIR="$INSTALL_DIR"
ARCHIVE_PATH="$REMOTE_ARCHIVE_PATH"
SPLUNK_REALM="$SPLUNK_REALM"
SPLUNK_ACCESS_TOKEN="$SPLUNK_ACCESS_TOKEN"
SPLUNK_INGEST_URL="https://ingest.$SPLUNK_REALM.observability.splunkcloud.com"
SPLUNK_API_URL="https://api.$SPLUNK_REALM.signalfx.com"
SPLUNK_HEC_URL="https://ingest.$SPLUNK_REALM.signalfx.com/v1/log"
USE_SPLUNK_INSTALLER="$USE_SPLUNK_INSTALLER"
COLLECTOR_CONFIG_PATH="/etc/otel/collector/agent_config.yaml"
COLLECTOR_ENV_PATH="/etc/otel/collector/splunk-otel-collector.conf"

write_minimal_collector_config() {
  sudo mkdir -p /etc/otel/collector
  sudo tee "\$COLLECTOR_CONFIG_PATH" >/dev/null <<CFG
extensions:
  health_check:
    endpoint: "127.0.0.1:13133"

receivers:
  otlp:
    protocols:
      grpc:
        endpoint: "127.0.0.1:4317"
      http:
        endpoint: "127.0.0.1:4318"

processors:
  memory_limiter:
    check_interval: 2s
    limit_mib: 460
    spike_limit_mib: 92
  batch:
    timeout: 30s
    send_batch_size: 90

exporters:
  otlp_http/traces:
    traces_endpoint: "\$SPLUNK_INGEST_URL/v2/trace/otlp"
    headers:
      X-SF-Token: "\$SPLUNK_ACCESS_TOKEN"
    compression: none
  otlp_http/metrics:
    metrics_endpoint: "\$SPLUNK_INGEST_URL/v2/datapoint/otlp"
    headers:
      X-SF-Token: "\$SPLUNK_ACCESS_TOKEN"
    compression: none

service:
  extensions: [health_check]
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlp_http/traces]
    metrics:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlp_http/metrics]
CFG
  sudo chmod 600 "\$COLLECTOR_CONFIG_PATH"
}

if [[ "\$USE_SPLUNK_INSTALLER" == "1" ]]; then
  if dpkg -s splunk-otel-collector >/dev/null 2>&1; then
    echo "collector_package_present=yes"
  else
    echo "collector_package_present=no"
    curl -sSL https://dl.observability.splunkcloud.com/splunk-otel-collector.sh -o /tmp/splunk-otel-collector.sh
    sudo env DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a sh /tmp/splunk-otel-collector.sh --realm "\$SPLUNK_REALM" --memory 512 --without-instrumentation --without-systemd-instrumentation -- "\$SPLUNK_ACCESS_TOKEN"
  fi

  sudo mkdir -p /etc/otel/collector
  if [[ -f "\$COLLECTOR_ENV_PATH" ]]; then
    sudo cp "\$COLLECTOR_ENV_PATH" "\$COLLECTOR_ENV_PATH.bak"
  fi
  sudo tee "\$COLLECTOR_ENV_PATH" >/dev/null <<CFG
SPLUNK_CONFIG=\$COLLECTOR_CONFIG_PATH
SPLUNK_ACCESS_TOKEN=\$SPLUNK_ACCESS_TOKEN
SPLUNK_REALM=\$SPLUNK_REALM
SPLUNK_INGEST_URL=\$SPLUNK_INGEST_URL
SPLUNK_API_URL=\$SPLUNK_API_URL
SPLUNK_HEC_URL=\$SPLUNK_HEC_URL
SPLUNK_HEC_TOKEN=\$SPLUNK_ACCESS_TOKEN
SPLUNK_MEMORY_TOTAL_MIB=512
OTELCOL_OPTIONS=--config=\$COLLECTOR_CONFIG_PATH
CFG
  sudo chmod 600 "\$COLLECTOR_ENV_PATH"
  write_minimal_collector_config
  sudo systemctl daemon-reload
  sudo systemctl enable splunk-otel-collector
  sudo systemctl restart splunk-otel-collector
else
  mkdir -p "\$INSTALL_DIR"
  tar -xzf "\$ARCHIVE_PATH" -C "\$INSTALL_DIR"

  COLLECTOR_BIN="\$(find "\$INSTALL_DIR" -maxdepth 3 -type f -name 'appdotelcol_*' | sort | head -n 1)"
  if [[ -z "\$COLLECTOR_BIN" ]]; then
    echo "ERROR: could not find appdotelcol_* under \$INSTALL_DIR" >&2
    exit 2
  fi
  chmod +x "\$COLLECTOR_BIN"

  cat > "\$INSTALL_DIR/otel-config.yaml" <<CFG
extensions:
  health_check:
    endpoint: "127.0.0.1:13133"

receivers:
  otlp:
    protocols:
      grpc:
        endpoint: "127.0.0.1:4317"
      http:
        endpoint: "127.0.0.1:4318"

processors:
  memory_limiter:
    check_interval: 2s
    limit_mib: 460
    spike_limit_mib: 92
  batch:
    timeout: 30s
    send_batch_size: 90

exporters:
  otlp_http/traces:
    traces_endpoint: https://ingest.\${SPLUNK_REALM}.observability.splunkcloud.com/v2/trace/otlp
    headers:
      X-SF-Token: \${SPLUNK_ACCESS_TOKEN}
    compression: none
  otlp_http/metrics:
    metrics_endpoint: https://ingest.\${SPLUNK_REALM}.observability.splunkcloud.com/v2/datapoint/otlp
    headers:
      X-SF-Token: \${SPLUNK_ACCESS_TOKEN}
    compression: none

service:
  extensions: [health_check]
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlp_http/traces]
    metrics:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlp_http/metrics]
CFG
  chmod 600 "\$INSTALL_DIR/otel-config.yaml"

  if pgrep -af 'appdotelcol_' >/dev/null 2>&1; then
    echo "collector_process_state=already_present"
    pgrep -af 'appdotelcol_' | sed -n '1,5p'
  fi

  nohup "\$COLLECTOR_BIN" --config "\$INSTALL_DIR/otel-config.yaml" >/tmp/appdotelcol.log 2>&1 < /dev/null &
fi
sleep 4

collector_ports="\$(ss -ltnp | egrep '(:4317|:4318)' || true)"
if [[ -n "\$collector_ports" ]]; then
  echo "collector_listener_present=yes"
  printf '%s\n' "\$collector_ports"
else
  echo "collector_listener_present=no"
fi
echo "collector_service_state=\$(systemctl is-active splunk-otel-collector 2>/dev/null || true)"
echo "collector_health_ok=\$(curl -fsS http://127.0.0.1:13133/ >/dev/null 2>&1 && echo yes || echo no)"
collector_recent_errors="\$(sudo journalctl -u splunk-otel-collector --since '-3 min' --no-pager 2>/dev/null | grep -E 'Exporting failed|authentication failed|Permanent error|failed to push|context deadline exceeded' | tail -n 20 || true)"
if [[ -n "\$collector_recent_errors" ]]; then
  echo "collector_recent_errors_present=yes"
  printf '%s\n' "\$collector_recent_errors"
else
  echo "collector_recent_errors_present=no"
fi
echo "---"
pgrep -af 'otelcol|appdotelcol_' | sed -n '1,8p' || true
echo "---"
sudo systemctl status splunk-otel-collector --no-pager -l | sed -n '1,30p' || true
echo "---"
if [[ -f /tmp/appdotelcol.log ]]; then
  tail -n 20 /tmp/appdotelcol.log || true
fi
EOF
)"

managed_via_control "$COLLECTOR_HOST" "$REMOTE_SCRIPT"
