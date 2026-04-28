# Current Smart Agent Lab

Use this reference when operating against the current AWS lab for this repo.

## Topology

- Region: `us-east-1`
- Public control host: `18.234.209.109`
- Control SSH user: `ubuntu`
- Control bundle directory: `/home/ubuntu/appdsm`
- Managed hosts are reached from the control host by private VPC IP:
  - `172.31.1.48` = `smartagent-1`
  - `172.31.1.142` = `smartagent-2`
  - `172.31.1.5` = `smartagent-3`
  - `172.31.1.243` = `smartagent-4`

## Validated Facts

- The live control-host bundle in `~/appdsm` is still `26.2.0-779` (live confirmed April 28, 2026).
- A staged `26.3.0-938` bundle exists on the control host in `/home/ubuntu/appdsm-26.3.0.938`.
- The rehearsed latest-bundle remote push path is `cd ~/appdsm-26.3.0.938 && sudo ./smartagentctl start --service --remote`.
- Managed Linux hosts run Smart Agent `26.3.0-938` from `/opt/appdynamics/appdsmartagent` (live confirmed for `smartagent-1`, `smartagent-2`, `smartagent-3`, `smartagent-4` on April 28, 2026).
- The control-host `smartagent.service` is currently active and the live remote.yaml lists 4 managed hosts, all running as `root:root`.
- The control host `remote.yaml` already follows the recommended demo pattern:
  - SSH login user `ubuntu`
  - `privileged: true`
  - managed-host Smart Agent runtime `root:root`
- The repo validation scripts now check that ownership model explicitly.
- The repo validation scripts now also gate on non-empty managed-host `config.ini` plus remote-push readiness for the SSH login user.
- For the current lab, `/opt/appdynamics/appdsmartagent` and `/opt/appdynamics/appdsmartagent/staging` on the managed Linux hosts must stay writable by `ubuntu` for latest-bundle remote push to work.
- **Validated live April 28, 2026:** all four managed hosts are at `root:ubuntu 775` on both paths after `prepare_remote_push.sh --profile <copied-profile> --execute`. `validate_lab.sh` passes `--require-windows-demo`, `--require-machine-agent`, and `--require-java-collector` with `rc=0` and no warnings.
- The Java demo app is `~/spring-petclinic`.
- `smartagent-1` is currently serving `HTTP/1.1 200` on port `8080` (live confirmed April 28, 2026).
- `smartagent-1` has a same-host `splunk-otel-collector` service running with healthy listeners on `127.0.0.1:4317` and `127.0.0.1:4318` and a passing health check on `127.0.0.1:13133` (live confirmed April 28, 2026). The collector binary is the upstream `splunk-otel-collector` package at `/usr/bin/otelcol` with config `/etc/otel/collector/agent_config.yaml`.
- `smartagent-2` has Node.js installed and returned `v22.22.0`.
- `smartagent-2` also has `~/weather-app/src`, and `node server.js` is listening on `3000`.
- The live `node server.js` process on `smartagent-2` is starting with `LD_PRELOAD=/opt/appdynamics/appdsmartagent/lib/libpreload.so`.
- `/opt/appdynamics/node-agent/appd-config.js` is present and configured for application `weather-app`, tier `weather-app`, and node `weather-app-s2`.
- The live Node agent log under `/tmp/appd/.../appd_node_agent_*.log` shows controller connection, node registration, and BT `/` registration.
- `smartagent-3` has an active `appdynamics-machine-agent.service`. As of April 28, 2026 it has been continuously active since April 24, 2026.
- The Windows host is intentionally pinned at `26.2.0-779` so the opening UI move can upgrade it to `26.3.0-938`.
- EC2Launch console output on April 22, 2026 showed the Windows hostname as `Smartagent-windows-1`.

## Bundle Inventory On Control Host

Three Smart Agent bundle directories live under `/home/ubuntu/` on the control host. Only the first two are part of the rehearsed live flow:

| Path | Smart Agent Version | Role | Owner | Notes |
| --- | --- | --- | --- | --- |
| `/home/ubuntu/appdsm` | `26.2.0-779` | Live control-host bundle. `smartagent.service` is wired to this directory. | `ubuntu:ubuntu` | Includes `id`, `set-appdynamics-env.sh`, `smartagent.service`, `store.json`. |
| `/home/ubuntu/appdsm-26.3.0.938` | `26.3.0-938` | Staged latest bundle for the rehearsed remote rollout (`sudo ./smartagentctl start --service --remote`). | `ubuntu:ubuntu` | Standard launcher contents, no `id` or `store.json`. |
| `/home/ubuntu/appdsm-archive/2026-04-20-smartagent2-targeted-push` | `26.3.0-938` | **Archived April 28, 2026** from `/home/ubuntu/appdsm-node-smartagent2`. Original was an ad-hoc, single-host `remote.yaml` targeted at `172.31.1.142` (`smartagent-2`), dated `2026-04-20 15:43`. Empty `.info.json`, embedded `log.log`. | `ubuntu:ubuntu` | Not part of any rehearsed flow. The `config.ini` carries a real `AccountAccessKey` for the `fso-tme` account, so leaving it under `appdsm-archive/` is acceptable for short-term forensic context only. **Action item:** purge the `appdsm-archive/` tree once the operator confirms the credential has been rotated or the bundle is no longer needed for forensic reference. |

## Next Rehearsal Targets

- Do one visual rehearsal of `Agent Management > Smart Agents > Upgrade` for `Smartagent-windows-1` before the room fills.
- Keep `smartagent-3` gated with `validate_lab.sh --require-machine-agent` before demo day.
- Purge `/home/ubuntu/appdsm-archive/` once the embedded `fso-tme` `AccountAccessKey` has been rotated (or once the archived bundle is confirmed unneeded for forensic reference).

## Operational Warnings

- The stale `/etc/environment` preload export was removed on April 20, 2026.
- Fresh SSH logins to the control host should no longer arrive with `LD_PRELOAD` set.
- `/etc/profile.d/set-appdynamics-env.sh` still exists, but it is not actively enabling the preload in the current lab.
- For backstage Windows hostname checks, prefer EC2 console output or System Properties over `$env:COMPUTERNAME`; Windows can expose a shortened 15-character form there.
- Do not use `smartagentctl status --remote` as a harmless read-only check on the current control host. During validation it stopped and synchronized remote Smart Agent services.
- Do not use `migrate --remote` from `26.3.0.938` as the rehearsed push path on already-enrolled hosts. With identical source and destination paths it can zero `config.ini` before the follow-up start step.
- `smartagent-4` is already enrolled, so it is not a true clean-target install demo unless it is reset first.
