#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
  COMMON_SH="$REPO_ROOT/skills/smartagent-lab/scripts/common.sh"
  STAGE_BUNDLE="$REPO_ROOT/skills/smartagent-lab/scripts/stage_bundle.sh"
  PREPARE_REMOTE_PUSH="$REPO_ROOT/skills/smartagent-lab/scripts/prepare_remote_push.sh"
  INSTALL_LOCAL_COLLECTOR="$REPO_ROOT/skills/smartagent-lab/scripts/install_local_collector.sh"
  VALIDATE_LAB="$REPO_ROOT/skills/smartagent-lab/scripts/validate_lab.sh"
  FIXTURE_DEFAULTS="$BATS_TEST_DIRNAME/fixtures/profile-defaults.yaml"
  FIXTURE_CUSTOM="$BATS_TEST_DIRNAME/fixtures/profile-custom-ownership.yaml"
  FIXTURE_MINIMAL="$BATS_TEST_DIRNAME/fixtures/profile-minimal.yaml"
  FIXTURE_MANAGED_ARGS="$BATS_TEST_DIRNAME/fixtures/profile-managed-ssh-args.yaml"
  FIXTURE_WINDOWS="$BATS_TEST_DIRNAME/fixtures/profile-windows-demo.yaml"
  BUNDLE_PATH="$REPO_ROOT/appdsmartagent_64_linux_26.3.0.938.zip"
}

@test "load_profile applies default ownership expectations" {
  run bash -lc "source '$COMMON_SH'; load_profile '$FIXTURE_DEFAULTS'; printf '%s|%s|%s|%s' \"\$EXPECTED_REMOTE_AUTH_USERNAME\" \"\$EXPECTED_REMOTE_PRIVILEGED\" \"\$EXPECTED_SMARTAGENT_USER\" \"\$EXPECTED_SMARTAGENT_GROUP\""
  [ "$status" -eq 0 ]
  [ "$output" = "ubuntu|true|root|root" ]
}

@test "load_profile honors explicit ownership expectations" {
  run bash -lc "source '$COMMON_SH'; load_profile '$FIXTURE_CUSTOM'; printf '%s|%s|%s|%s' \"\$EXPECTED_REMOTE_AUTH_USERNAME\" \"\$EXPECTED_REMOTE_PRIVILEGED\" \"\$EXPECTED_SMARTAGENT_USER\" \"\$EXPECTED_SMARTAGENT_GROUP\""
  [ "$status" -eq 0 ]
  [ "$output" = "svc-smartagent|false|svc-agent|svc-observers" ]
}

@test "load_profile reads Windows demo metadata" {
  run bash -lc "source '$COMMON_SH'; load_profile '$FIXTURE_WINDOWS'; printf '%s|%s|%s|%s|%s' \"\$WINDOWS_DEMO_HOST_LABEL\" \"\$WINDOWS_DEMO_EXPECTED_HOSTNAME\" \"\$WINDOWS_DEPLOYMENT_GROUP\" \"\$WINDOWS_DEMO_CURRENT_VERSION\" \"\$WINDOWS_DEMO_TARGET_VERSION\""
  [ "$status" -eq 0 ]
  [ "$output" = "Smartagent-windows-1|Smartagent-windows-1|Windows Smart Agent Upgrade|26.2.0-779|26.3.0-938" ]
}

@test "build_managed_ssh_command uses sshpass when managed password is set" {
  run bash -lc "source '$COMMON_SH'; load_profile '$FIXTURE_DEFAULTS'; export SMARTAGENT_MANAGED_SSH_PASSWORD='Pa ss!'; build_managed_ssh_command '172.31.1.48'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"sshpass -p"* ]]
  [[ "$output" == *"PreferredAuthentications=password"* ]]
  [[ "$output" != *"BatchMode=yes"* ]]
  [[ "$output" == *"ubuntu@172.31.1.48"* ]]
}

@test "build_managed_ssh_command preserves list-style SSH args with spaces" {
  run bash -lc "source '$COMMON_SH'; load_profile '$FIXTURE_MANAGED_ARGS'; build_managed_ssh_command '10.0.0.10'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ProxyCommand=ssh\\ -W\\ %h:%p\\ jump.internal"* ]]
  [[ "$output" == *"ubuntu@10.0.0.10"* ]]
}

@test "managed_copy_via_control keeps explicit source paths intact" {
  run bash -lc "source '$COMMON_SH'; load_profile '$FIXTURE_DEFAULTS'; control_ssh_stream() { printf '%s\n' \"\$1\"; }; managed_copy_via_control '172.31.1.48' '/home/ubuntu/test.tgz' '/home/ubuntu/test.tgz'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"/home/ubuntu/test.tgz"* ]]
  [[ "$output" != *"\\\$HOME/test.tgz"* ]]
}

@test "stage_bundle dry run reports the derived staging directory" {
  run bash "$STAGE_BUNDLE" --profile "$FIXTURE_DEFAULTS" --bundle "$BUNDLE_PATH"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Dry run only. No files will be copied."* ]]
  [[ "$output" == *"/home/ubuntu/appdsm-26.3.0.938"* ]]
}

@test "prepare_remote_push dry run shows the managed directory fix" {
  run bash "$PREPARE_REMOTE_PUSH" --profile "$FIXTURE_DEFAULTS"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Dry run only. Planned managed-host commands:"* ]]
  [[ "$output" == *"sudo chgrp \"ubuntu\" /opt/appdynamics/appdsmartagent /opt/appdynamics/appdsmartagent/staging"* ]]
}

@test "validate_lab main exits non-zero when a critical marker fails" {
  run bash -lc "source '$VALIDATE_LAB'
control_ssh_stream() {
  cat <<'EOF'
control-node
bundle_dir=/home/ubuntu/appdsm
bundle_dir_exists=yes
bundle_cli_exists=yes
26.2.0-779
control_smartagent_state=active
control_smartagent_active=yes
control_service_user=root
control_service_group=root
---
ld_preload_reference_present=no
---
remote_yaml_exists=yes
remote_auth_username_ok=no
remote_privileged_ok=yes
remote_runtime_identity_ok=yes
remote_host_count=1
---
/home/ubuntu/appdsm
EOF
}
managed_via_control() {
  cat <<'EOF'
managed-node
smartagent_active_state=active
smartagent_active=yes
smartagent_cli_exists=yes
26.2.0-779
smartagent_service_user=root
smartagent_service_group=root
smartagent_service_identity_ok=yes
smartagent_config_nonempty=yes
smartagent_remote_push_root_writable=yes
smartagent_remote_push_staging_writable=yes
root root smartagent
EOF
}
main --profile '$FIXTURE_MINIMAL'"
  [ "$status" -eq 1 ]
  [[ "$output" == *"VALIDATION ERROR: remote.yaml SSH username does not match the expected value"* ]]
  [[ "$output" == *"Validation failed with 1 critical issue(s)."* ]]
}

@test "validate_lab main exits zero when critical markers pass" {
  run bash -lc "source '$VALIDATE_LAB'
control_ssh_stream() {
  cat <<'EOF'
control-node
bundle_dir=/home/ubuntu/appdsm
bundle_dir_exists=yes
bundle_cli_exists=yes
26.2.0-779
control_smartagent_state=active
control_smartagent_active=yes
control_service_user=root
control_service_group=root
---
ld_preload_reference_present=no
---
remote_yaml_exists=yes
remote_auth_username_ok=yes
remote_privileged_ok=yes
remote_runtime_identity_ok=yes
remote_host_count=1
---
/home/ubuntu/appdsm
EOF
}
managed_via_control() {
  cat <<'EOF'
managed-node
smartagent_active_state=active
smartagent_active=yes
smartagent_cli_exists=yes
26.2.0-779
smartagent_service_user=root
smartagent_service_group=root
smartagent_service_identity_ok=yes
smartagent_config_nonempty=yes
smartagent_remote_push_root_writable=yes
smartagent_remote_push_staging_writable=yes
root root smartagent
EOF
}
main --profile '$FIXTURE_MINIMAL'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Validation passed with no critical issues."* ]]
}

@test "validate_lab fails when Java collector is required but absent" {
  run bash -lc "source '$VALIDATE_LAB'
control_ssh_stream() {
  cat <<'EOF'
control-node
bundle_dir=/home/ubuntu/appdsm
bundle_dir_exists=yes
bundle_cli_exists=yes
26.2.0-779
control_smartagent_state=active
control_smartagent_active=yes
control_service_user=root
control_service_group=root
---
ld_preload_reference_present=no
---
remote_yaml_exists=yes
remote_auth_username_ok=yes
remote_privileged_ok=yes
remote_runtime_identity_ok=yes
remote_host_count=1
---
/home/ubuntu/appdsm
EOF
}
managed_via_control() {
  cat <<'EOF'
managed-node
smartagent_active_state=active
smartagent_active=yes
smartagent_cli_exists=yes
26.2.0-779
smartagent_service_user=root
smartagent_service_group=root
smartagent_service_identity_ok=yes
smartagent_config_nonempty=yes
smartagent_remote_push_root_writable=yes
smartagent_remote_push_staging_writable=yes
root root smartagent
java_demo_dir_exists=yes
run_app_exists=yes
java_demo_http_status=200
java_demo_http_ok=yes
java_collector_listener=no
java_collector_service_state=inactive
java_collector_service_active=no
java_collector_health_ok=no
java_collector_recent_errors=no
node_runtime_present=yes
machine_agent_active_state=failed
machine_agent_active=no
EOF
}
main --profile '$FIXTURE_DEFAULTS' --require-java-collector"
  [ "$status" -eq 1 ]
  [[ "$output" == *"VALIDATION ERROR: Java demo host 172.31.1.48 does not have a local collector listening on 4317 or 4318"* ]]
}

@test "validate_lab fails when remote push prerequisites drift" {
  run bash -lc "source '$VALIDATE_LAB'
control_ssh_stream() {
  cat <<'EOF'
control-node
bundle_dir=/home/ubuntu/appdsm
bundle_dir_exists=yes
bundle_cli_exists=yes
26.3.0-938
control_smartagent_state=active
control_smartagent_active=yes
control_service_user=root
control_service_group=root
---
ld_preload_reference_present=no
---
remote_yaml_exists=yes
remote_auth_username_ok=yes
remote_privileged_ok=yes
remote_runtime_identity_ok=yes
remote_host_count=1
---
/home/ubuntu/appdsm
/home/ubuntu/appdsm-26.3.0.938
EOF
}
managed_via_control() {
  cat <<'EOF'
managed-node
smartagent_active_state=active
smartagent_active=yes
smartagent_cli_exists=yes
26.3.0-938
smartagent_service_user=root
smartagent_service_group=root
smartagent_service_identity_ok=yes
smartagent_config_nonempty=no
smartagent_remote_push_root_writable=no
smartagent_remote_push_staging_writable=yes
root root smartagent
EOF
}
main --profile '$FIXTURE_MINIMAL'"
  [ "$status" -eq 1 ]
  [[ "$output" == *"VALIDATION ERROR: managed host 10.0.0.10 has an empty /opt/appdynamics/appdsmartagent/config.ini"* ]]
  [[ "$output" == *"VALIDATION ERROR: managed host 10.0.0.10 does not let ubuntu write /opt/appdynamics/appdsmartagent for remote push"* ]]
}

@test "validate_lab fails when Windows demo metadata is required but missing" {
  run bash -lc "source '$VALIDATE_LAB'
control_ssh_stream() {
  cat <<'EOF'
control-node
bundle_dir=/home/ubuntu/appdsm
bundle_dir_exists=yes
bundle_cli_exists=yes
26.3.0-938
control_smartagent_state=active
control_smartagent_active=yes
control_service_user=root
control_service_group=root
---
ld_preload_reference_present=no
---
remote_yaml_exists=yes
remote_auth_username_ok=yes
remote_privileged_ok=yes
remote_runtime_identity_ok=yes
remote_host_count=1
---
/home/ubuntu/appdsm
EOF
}
managed_via_control() {
  cat <<'EOF'
managed-node
smartagent_active_state=active
smartagent_active=yes
smartagent_cli_exists=yes
26.3.0-938
smartagent_service_user=root
smartagent_service_group=root
smartagent_service_identity_ok=yes
smartagent_config_nonempty=yes
smartagent_remote_push_root_writable=yes
smartagent_remote_push_staging_writable=yes
root root smartagent
EOF
}
main --profile '$FIXTURE_MINIMAL' --require-windows-demo"
  [ "$status" -eq 1 ]
  [[ "$output" == *"VALIDATION ERROR: Windows demo host label is not pinned in the copied profile"* ]]
  [[ "$output" == *"VALIDATION ERROR: Windows demo current version is not pinned in the copied profile"* ]]
}

@test "validate_lab passes when Windows demo metadata is pinned for an upgrade" {
  run bash -lc "source '$VALIDATE_LAB'
control_ssh_stream() {
  cat <<'EOF'
control-node
bundle_dir=/home/ubuntu/appdsm
bundle_dir_exists=yes
bundle_cli_exists=yes
26.3.0-938
control_smartagent_state=active
control_smartagent_active=yes
control_service_user=root
control_service_group=root
---
ld_preload_reference_present=no
---
remote_yaml_exists=yes
remote_auth_username_ok=yes
remote_privileged_ok=yes
remote_runtime_identity_ok=yes
remote_host_count=1
---
/home/ubuntu/appdsm
EOF
}
managed_via_control() {
  cat <<'EOF'
managed-node
smartagent_active_state=active
smartagent_active=yes
smartagent_cli_exists=yes
26.3.0-938
smartagent_service_user=root
smartagent_service_group=root
smartagent_service_identity_ok=yes
smartagent_config_nonempty=yes
smartagent_remote_push_root_writable=yes
smartagent_remote_push_staging_writable=yes
root root smartagent
EOF
}
main --profile '$FIXTURE_WINDOWS' --require-windows-demo"
  [ "$status" -eq 0 ]
  [[ "$output" == *"windows_demo_upgrade_direction_ok=yes"* ]]
  [[ "$output" == *"Validation passed with no critical issues."* ]]
}

@test "install_local_collector dry run shows the managed collector plan" {
  run env SPLUNK_REALM=us1 SPLUNK_ACCESS_TOKEN=dummy bash "$INSTALL_LOCAL_COLLECTOR" --profile "$FIXTURE_DEFAULTS" --archive "$BUNDLE_PATH"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Dry run only. Planned steps:"* ]]
  [[ "$output" == *"Write otel-config.yaml with Splunk OTLP/HTTP trace and metric export."* ]]
}

@test "install_local_collector supports the Splunk installer dry run path" {
  run env SPLUNK_REALM=us1 SPLUNK_ACCESS_TOKEN=dummy bash "$INSTALL_LOCAL_COLLECTOR" --profile "$FIXTURE_DEFAULTS" --use-splunk-installer
  [ "$status" -eq 0 ]
  [[ "$output" == *"Collector source: official Splunk Linux installer"* ]]
  [[ "$output" == *"Write a minimal local-collector config for OTel -> O11y forwarding."* ]]
}

@test "install_local_collector rejects install-dir in installer mode" {
  run env SPLUNK_REALM=us1 SPLUNK_ACCESS_TOKEN=dummy bash "$INSTALL_LOCAL_COLLECTOR" --profile "$FIXTURE_DEFAULTS" --use-splunk-installer --install-dir /tmp/demo
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: --install-dir is only supported with --archive"* ]]
}
