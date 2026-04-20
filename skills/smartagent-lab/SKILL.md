---
name: smartagent-lab
description: Use when preparing, staging, validating, or documenting a repeatable Splunk AppDynamics Smart Agent lab, especially when a public control host manages private-VPC targets and brownfield Java demo apps.
---

# SmartAgent Lab

Use this skill for repeatable Smart Agent lab work in this repo and similar environments.

## Start Here

- Read [`references/lab-profile.example.yaml`](references/lab-profile.example.yaml) first. It defines the operator inputs the scripts expect.
- Copy [`/Users/alecchamberlain/Documents/GitHub/smartagent_clus26/smartagent-lab-credentials.example.env`](/Users/alecchamberlain/Documents/GitHub/smartagent_clus26/smartagent-lab-credentials.example.env) to a filled-in local credentials file before rehearsing or teaching the demo, keep that filled-in copy outside the repo or untracked, and source it in the shell that will actually run the demo commands.
- Read [`references/current-lab.md`](references/current-lab.md) when working on the current AWS lab.
- Prefer the bundled scripts over retyping long SSH flows.
- Prefer list-style `control_ssh_args` and `managed_ssh_args` in the profile over free-form SSH option strings.

## Network Model

- Treat the control host as the only operator entry point.
- Reach managed hosts by private VPC IP from the control host.
- Do not assume the operator workstation can talk directly to managed hosts.
- Use the control host to simulate the on-prem management pattern.

## Default Safety Mode

- Stage and verify by default.
- Preserve the active `config.ini` and `remote.yaml` when staging a new bundle.
- Do not cut over the active control-host bundle unless the user explicitly asks.
- Do not treat `smartagentctl status --remote` as harmless on the current lab.
- Validate the remote SSH user and Smart Agent `user` / `group` model before rehearsing.
- Treat `scripts/validate_lab.sh` as a real gate: it exits non-zero on critical drift and only leaves appendix checks as warnings.

## Scripts

- `scripts/stage_bundle.sh`: stage a new Smart Agent bundle on the control host. Dry-run by default.
- `scripts/prepare_remote_push.sh`: make managed-host install directories writable by the remote SSH user before or after a latest-bundle remote rollout. Dry-run by default.
- `scripts/validate_lab.sh`: run read-only validation through the control host against private-IP targets.
- `scripts/start_java_demo.sh`: print the Java brownfield startup flow by default, execute only with `--execute`.
- `scripts/install_local_collector.sh`: stage and start a local collector on the Java demo host. Dry-run by default.

## Auth Expectations

- The scripts connect from the operator workstation to the control host.
- If the control host uses password auth, set `SMARTAGENT_CONTROL_SSH_PASSWORD` before running the scripts.
- If the control host must use password auth to reach managed hosts, set `SMARTAGENT_MANAGED_SSH_PASSWORD` and ensure `sshpass` is installed on the control host.
- The control host is expected to have its own SSH path to the managed private-IP hosts.

## Current Lab Caveats

- The durable control-host `LD_PRELOAD` fix is already applied in the current lab. If a reused shell still carries it, reconnect or `unset LD_PRELOAD`.
- The current lab uses `~/appdsm` on the control host and `/opt/appdynamics/appdsmartagent` on managed Linux hosts.
- The Java brownfield app is `~/spring-petclinic`.
- If the lab needs a local collector for Java dual mode, prefer `scripts/install_local_collector.sh --use-splunk-installer` with the Splunk realm and access token. Keep the Linux AMD64 archive only as a restricted-egress fallback.
- Keep Node.js optional unless the app is already staged.
- Keep Machine Agent in appendix until the missing binary path is repaired.

## Docs

After validation changes the lab truth, keep these aligned:

- `/Users/alecchamberlain/Documents/GitHub/smartagent_clus26/smartagent-demo-script.md`
- `/Users/alecchamberlain/Documents/GitHub/smartagent_clus26/smartagent-lab-guide.md`
- `/Users/alecchamberlain/Documents/GitHub/smartagent_clus26/smartagent-architecture.md`
