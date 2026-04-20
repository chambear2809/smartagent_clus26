#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=skills/smartagent-lab/scripts/common.sh
source "$SCRIPT_DIR/common.sh"

usage() {
  cat <<'EOF'
Usage:
  stage_bundle.sh --profile <path> [--bundle <zip>] [--execute] [--force]

Behavior:
  - Dry-run by default
  - Stages a new Smart Agent bundle into a versioned directory on the control host
  - Preserves the current config.ini
  - Preserves remote.yaml when present
  - Does not replace the active bundle directory
EOF
}

PROFILE=""
BUNDLE=""
EXECUTE=0
FORCE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      PROFILE="${2:-}"
      shift 2
      ;;
    --bundle)
      BUNDLE="${2:-}"
      shift 2
      ;;
    --execute)
      EXECUTE=1
      shift
      ;;
    --force)
      FORCE=1
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

if [[ -z "$BUNDLE" ]]; then
  [[ -n "${SMARTAGENT_BUNDLE_FILENAME:-}" ]] || die "No bundle provided and smartagent_bundle_filename is empty in the profile"
  BUNDLE="$SMARTAGENT_BUNDLE_FILENAME"
fi

[[ -f "$BUNDLE" ]] || die "Bundle not found: $BUNDLE"

BUNDLE_NAME="$(basename "$BUNDLE")"
VERSION="$(parse_bundle_version "$BUNDLE_NAME")"
LIVE_DIR="$CONTROL_BUNDLE_DIR"
LIVE_PARENT="$(dirname "$LIVE_DIR")"
LIVE_BASENAME="$(basename "$LIVE_DIR")"
STAGE_DIR="${LIVE_PARENT}/${LIVE_BASENAME}-${VERSION}"

note "Lab: ${LAB_NAME:-unknown}"
note "Control host: $CONTROL_HOST"
note "Live bundle dir: $LIVE_DIR"
note "Stage dir: $STAGE_DIR"
note "Bundle: $BUNDLE"
note "Version: $VERSION"

if [[ "$EXECUTE" -eq 0 ]]; then
  note
  note "Dry run only. No files will be copied."
  note "Next step:"
  note "  $0 --profile $PROFILE --bundle $BUNDLE --execute"
  exit 0
fi

note "Uploading bundle to control host..."
control_scp_to_home "$BUNDLE" "$BUNDLE_NAME"

REMOTE_SCRIPT="$(cat <<EOF
set -euo pipefail
unset LD_PRELOAD || true

LIVE_DIR="$LIVE_DIR"
STAGE_DIR="$STAGE_DIR"
BUNDLE_NAME="$BUNDLE_NAME"
CONTROL_USER="$CONTROL_SSH_USER"
FORCE_FLAG="$FORCE"

if [[ -e "\$STAGE_DIR" ]]; then
  if [[ "\$FORCE_FLAG" != "1" ]]; then
    echo "ERROR: stage directory already exists: \$STAGE_DIR" >&2
    exit 2
  fi
  rm -rf "\$STAGE_DIR"
fi

mkdir -p "\$STAGE_DIR"
unzip -oq "$HOME/\$BUNDLE_NAME" -d "\$STAGE_DIR"
sudo cp "\$LIVE_DIR/config.ini" "\$STAGE_DIR/config.ini"
if [[ -f "\$LIVE_DIR/remote.yaml" ]]; then
  sudo cp "\$LIVE_DIR/remote.yaml" "\$STAGE_DIR/remote.yaml"
fi
sudo chown "\$CONTROL_USER:\$CONTROL_USER" "\$STAGE_DIR/config.ini"
if [[ -f "\$STAGE_DIR/remote.yaml" ]]; then
  sudo chown "\$CONTROL_USER:\$CONTROL_USER" "\$STAGE_DIR/remote.yaml"
fi

ls -la "\$STAGE_DIR"
echo "---"
"\$STAGE_DIR/smartagentctl" --version
echo "---"
sudo grep -n 'ControllerURL\\|ControllerPort\\|AccountName\\|EnableSSL' "\$STAGE_DIR/config.ini" || true
EOF
)"

control_ssh_stream "$REMOTE_SCRIPT"
