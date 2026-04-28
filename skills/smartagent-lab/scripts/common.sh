#!/usr/bin/env bash

set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

note() {
  printf '%s\n' "$*"
}

trim_quotes() {
  local value="$1"
  value="${value%\"}"
  value="${value#\"}"
  value="${value%\'}"
  value="${value#\'}"
  printf '%s' "$value"
}

quote_for_shell() {
  printf '%q' "$1"
}

yaml_scalar() {
  local file="$1"
  local key="$2"

  awk -v key="$key" '
    /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
    $0 ~ ("^" key ":[[:space:]]*$") { print ""; exit }
    $0 ~ ("^" key ":[[:space:]]*") {
      sub("^" key ":[[:space:]]*", "", $0)
      print $0
      exit
    }
  ' "$file" | {
    local value
    IFS= read -r value || true
    trim_quotes "$value"
  }
}

yaml_list() {
  local file="$1"
  local key="$2"

  awk -v key="$key" '
    /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
    $0 ~ ("^" key ":[[:space:]]*$") { in_list=1; next }
    in_list && $0 ~ /^  - / {
      sub(/^  -[[:space:]]*/, "", $0)
      print $0
      next
    }
    in_list && $0 ~ /^[^[:space:]]/ { exit }
  ' "$file" | while IFS= read -r item; do
    trim_quotes "$item"
    printf '\n'
  done
}

load_yaml_list() {
  local file="$1"
  local key="$2"
  local var_name="$3"
  local item

  eval "$var_name=()"
  while IFS= read -r item; do
    [[ -n "$item" ]] || continue
    eval "$var_name+=(\"\$item\")"
  done < <(yaml_list "$file" "$key")
}

require_scalar() {
  local file="$1"
  local key="$2"
  local value
  value="$(yaml_scalar "$file" "$key")"
  [[ -n "$value" ]] || die "Missing required key '$key' in $file"
  printf '%s' "$value"
}

parse_bundle_version() {
  local bundle_name="$1"
  if [[ "$bundle_name" =~ ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+) ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
    return 0
  fi
  die "Could not parse Smart Agent version from bundle name: $bundle_name"
}

load_profile() {
  # shellcheck disable=SC2034
  local profile="$1"
  [[ -f "$profile" ]] || die "Profile not found: $profile"

  PROFILE_PATH="$profile"
  LAB_NAME="$(yaml_scalar "$profile" lab_name)"
  REGION="$(yaml_scalar "$profile" region)"
  CONTROL_HOST="$(require_scalar "$profile" control_host)"
  CONTROL_SSH_USER="$(yaml_scalar "$profile" control_ssh_user)"
  [[ -n "$CONTROL_SSH_USER" ]] || CONTROL_SSH_USER="$(require_scalar "$profile" ssh_user)"
  CONTROL_SSH_OPTIONS_RAW="$(yaml_scalar "$profile" control_ssh_options)"
  CONTROL_BUNDLE_DIR="$(require_scalar "$profile" control_bundle_dir)"
  MANAGED_SSH_USER="$(yaml_scalar "$profile" managed_ssh_user)"
  [[ -n "$MANAGED_SSH_USER" ]] || MANAGED_SSH_USER="$CONTROL_SSH_USER"
  MANAGED_SSH_OPTIONS_RAW="$(yaml_scalar "$profile" managed_ssh_options)"
  JAVA_DEMO_HOST="$(yaml_scalar "$profile" java_demo_host)"
  JAVA_DEMO_DIR="$(yaml_scalar "$profile" java_demo_dir)"
  NODE_DEMO_HOST="$(yaml_scalar "$profile" node_demo_host)"
  INFRA_HOST="$(yaml_scalar "$profile" infra_host)"
  WINDOWS_DEMO_HOST_LABEL="$(yaml_scalar "$profile" windows_demo_host_label)"
  WINDOWS_DEMO_EXPECTED_HOSTNAME="$(yaml_scalar "$profile" windows_demo_expected_hostname)"
  WINDOWS_DEPLOYMENT_GROUP="$(yaml_scalar "$profile" windows_deployment_group)"
  WINDOWS_DEMO_CURRENT_VERSION="$(yaml_scalar "$profile" windows_demo_current_version)"
  WINDOWS_DEMO_TARGET_VERSION="$(yaml_scalar "$profile" windows_demo_target_version)"
  CONTROLLER_URL="$(yaml_scalar "$profile" controller_url)"
  CONTROLLER_ACCOUNT_NAME="$(yaml_scalar "$profile" controller_account_name)"
  SPLUNK_REALM="$(yaml_scalar "$profile" splunk_realm)"
  SMARTAGENT_BUNDLE_FILENAME="$(yaml_scalar "$profile" smartagent_bundle_filename)"
  EXPECTED_REMOTE_AUTH_USERNAME="$(yaml_scalar "$profile" expected_remote_auth_username)"
  [[ -n "$EXPECTED_REMOTE_AUTH_USERNAME" ]] || EXPECTED_REMOTE_AUTH_USERNAME="$MANAGED_SSH_USER"
  EXPECTED_REMOTE_PRIVILEGED="$(yaml_scalar "$profile" expected_remote_privileged)"
  [[ -n "$EXPECTED_REMOTE_PRIVILEGED" ]] || EXPECTED_REMOTE_PRIVILEGED="true"
  EXPECTED_SMARTAGENT_USER="$(yaml_scalar "$profile" expected_smartagent_user)"
  [[ -n "$EXPECTED_SMARTAGENT_USER" ]] || EXPECTED_SMARTAGENT_USER="root"
  EXPECTED_SMARTAGENT_GROUP="$(yaml_scalar "$profile" expected_smartagent_group)"
  [[ -n "$EXPECTED_SMARTAGENT_GROUP" ]] || EXPECTED_SMARTAGENT_GROUP="root"

  load_yaml_list "$profile" control_ssh_args CONTROL_SSH_ARGS
  if [[ "${#CONTROL_SSH_ARGS[@]}" -eq 0 && -n "${CONTROL_SSH_OPTIONS_RAW:-}" ]]; then
    split_legacy_options "$CONTROL_SSH_OPTIONS_RAW" CONTROL_SSH_ARGS
  fi

  load_yaml_list "$profile" managed_ssh_args MANAGED_SSH_ARGS
  if [[ "${#MANAGED_SSH_ARGS[@]}" -eq 0 && -n "${MANAGED_SSH_OPTIONS_RAW:-}" ]]; then
    split_legacy_options "$MANAGED_SSH_OPTIONS_RAW" MANAGED_SSH_ARGS
  fi

  load_yaml_list "$profile" managed_hosts MANAGED_HOSTS
  load_yaml_list "$profile" remote_targets REMOTE_TARGETS
}

split_legacy_options() {
  local raw="$1"
  local var_name="$2"
  eval "$var_name=()"
  if [[ -n "$raw" ]]; then
    local parsed=()
    read -r -a parsed <<< "$raw"
    local item
    for item in "${parsed[@]}"; do
      eval "$var_name+=(\"\$item\")"
    done
  fi
}

filtered_managed_ssh_args() {
  local i arg next_arg

  for ((i = 0; i < ${#MANAGED_SSH_ARGS[@]}; i++)); do
    arg="${MANAGED_SSH_ARGS[$i]}"
    next_arg=""
    if (( i + 1 < ${#MANAGED_SSH_ARGS[@]} )); then
      next_arg="${MANAGED_SSH_ARGS[$((i + 1))]}"
    fi

    if [[ -n "${SMARTAGENT_MANAGED_SSH_PASSWORD:-}" ]]; then
      if [[ "$arg" == "-o" && "$next_arg" == "BatchMode=yes" ]]; then
        i=$((i + 1))
        continue
      fi
      if [[ "$arg" == "-oBatchMode=yes" ]]; then
        continue
      fi
    fi

    printf '%s\0' "$arg"
  done
}

join_shell_words() {
  local joined=""
  local word
  for word in "$@"; do
    joined+="$(quote_for_shell "$word") "
  done
  printf '%s' "${joined% }"
}

control_ssh_stream() {
  local script="$1"
  local -a cmd=()

  if [[ -n "${SMARTAGENT_CONTROL_SSH_PASSWORD:-}" ]]; then
    cmd=(sshpass -p "$SMARTAGENT_CONTROL_SSH_PASSWORD" ssh -o PubkeyAuthentication=no -o PreferredAuthentications=password)
  else
    cmd=(ssh)
  fi

  cmd+=("${CONTROL_SSH_ARGS[@]}")
  cmd+=("${CONTROL_SSH_USER}@${CONTROL_HOST}" "bash -s")

  printf '%s\n' "$script" | "${cmd[@]}"
}

control_scp_to_home() {
  local local_path="$1"
  local remote_name="${2:-$(basename "$local_path")}"
  local -a cmd=()

  if [[ -n "${SMARTAGENT_CONTROL_SSH_PASSWORD:-}" ]]; then
    cmd=(sshpass -p "$SMARTAGENT_CONTROL_SSH_PASSWORD" scp -o PubkeyAuthentication=no -o PreferredAuthentications=password)
  else
    cmd=(scp)
  fi

  cmd+=("${CONTROL_SSH_ARGS[@]}")
  cmd+=("$local_path" "${CONTROL_SSH_USER}@${CONTROL_HOST}:${remote_name}")
  "${cmd[@]}"
}

build_managed_ssh_command() {
  local managed_host="$1"
  local -a command_words=()

  if [[ -n "${SMARTAGENT_MANAGED_SSH_PASSWORD:-}" ]]; then
    command_words=(sshpass -p "$SMARTAGENT_MANAGED_SSH_PASSWORD" ssh -o PubkeyAuthentication=no -o PreferredAuthentications=password)
  else
    command_words=(ssh)
  fi

  while IFS= read -r -d '' arg; do
    command_words+=("$arg")
  done < <(filtered_managed_ssh_args)
  command_words+=("${MANAGED_SSH_USER}@${managed_host}" "bash -s")

  join_shell_words "${command_words[@]}"
}

build_managed_scp_command() {
  local managed_host="$1"
  local source_path="$2"
  local dest_path="$3"
  local -a command_words=()

  if [[ -n "${SMARTAGENT_MANAGED_SSH_PASSWORD:-}" ]]; then
    command_words=(sshpass -p "$SMARTAGENT_MANAGED_SSH_PASSWORD" scp -o PubkeyAuthentication=no -o PreferredAuthentications=password)
  else
    command_words=(scp)
  fi

  while IFS= read -r -d '' arg; do
    command_words+=("$arg")
  done < <(filtered_managed_ssh_args)
  command_words+=("$source_path" "${MANAGED_SSH_USER}@${managed_host}:$dest_path")

  join_shell_words "${command_words[@]}"
}

managed_via_control() {
  local managed_host="$1"
  local managed_script="$2"
  local control_script
  local managed_command
  local managed_password_block=""

  managed_command="$(build_managed_ssh_command "$managed_host")"
  if [[ -n "${SMARTAGENT_MANAGED_SSH_PASSWORD:-}" ]]; then
    managed_password_block="$(cat <<'EOF'
if ! command -v sshpass >/dev/null 2>&1; then
  echo "ERROR: SMARTAGENT_MANAGED_SSH_PASSWORD is set but sshpass is not installed on the control host" >&2
  exit 97
fi
EOF
)"
  fi

  control_script="$(cat <<EOF
set -euo pipefail
unset LD_PRELOAD || true
${managed_password_block}
cat <<'INNER' | ${managed_command}
${managed_script}
INNER
EOF
)"

  control_ssh_stream "$control_script"
}

managed_copy_via_control() {
  local managed_host="$1"
  local source_path="$2"
  local dest_path="$3"
  local copy_command
  local managed_password_block=""
  local control_script

  copy_command="$(build_managed_scp_command "$managed_host" "$source_path" "$dest_path")"
  if [[ -n "${SMARTAGENT_MANAGED_SSH_PASSWORD:-}" ]]; then
    managed_password_block="$(cat <<'EOF'
if ! command -v sshpass >/dev/null 2>&1; then
  echo "ERROR: SMARTAGENT_MANAGED_SSH_PASSWORD is set but sshpass is not installed on the control host" >&2
  exit 97
fi
EOF
)"
  fi

  control_script="$(cat <<EOF
set -euo pipefail
unset LD_PRELOAD || true
${managed_password_block}
${copy_command}
EOF
)"

  control_ssh_stream "$control_script"
}
