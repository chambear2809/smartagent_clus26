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
- `splunk-otel-collector.service` is **not** installed on `smartagent-3`. CMA dual-signal mode on a systemd host defers OTel collector lifecycle to that separate service, so a live `SPLUNK_OTEL_ENABLED=true` flip on `smartagent-3` will keep AppD reporting healthy but emit no OTel data until the collector is installed (validated live April 28, 2026: `systemctl list-unit-files | grep -i otel` returns no rows on `smartagent-3`; no `splunk-otel*` package is installed).
- The active Java Agent on `smartagent-1` is `25.12.0.37551` under `/opt/appdynamics/appdsmartagent/profile/java/ver25.12.0.37551/`. The bundled OTel Java Agent is `splunk-otel-javaagent-2.22.0.jar` under `/opt/appdynamics/appdsmartagent/profile/java/otel/`.
- Smart Agent libpreload auto-attach on `smartagent-1` was repaired April 28, 2026. Two filter `agentPath` entries in `/opt/appdynamics/appdsmartagent/lib/ld_preload.json` (`springboot` and `plain java`) had been pointing at the bare directory `.../profile/java`, which broke every new Spring Boot brownfield JVM with `Error opening zip file or JAR manifest missing : .../profile/java`. After rewriting both `agentPath` values to `.../profile/java/javaagent.jar`, the documented `bash -lc 'cd ~/spring-petclinic && nohup ./run-app.sh ...'` flow attaches `javaagent.jar` plus `splunk-otel-javaagent-2.22.0.jar` cleanly with `LD_PRELOAD=/opt/appdynamics/appdsmartagent/lib/libpreload.so`, no `_JAVA_OPTIONS`, and `Server-Timing: traceparent` on the response. The pre-fix `ld_preload.json` is preserved on the host as `ld_preload.json.bak.20260428T155137Z`.
- The AppD Java Agent per-node log directory `/opt/appdynamics/appdsmartagent/profile/java/ver25.12.0.37551/logs/` was `chown`'d to `ubuntu:ubuntu` on April 28, 2026 so the JVM (running as `ubuntu`) can create the per-node `pet_smartagent-1/` log directory cleanly. Without this fix the AppD log4j init fails with `Could not create directory ... pet_smartagent-1` even though the agent is otherwise reporting.
- `/opt/appdynamics/appdsmartagent/profile/java/.manage/info.json` on `smartagent-1` was hardened from mode `0644` to `0640 root:root` on April 28, 2026 because it contains a real `controller_account_access_key`. Smart Agent runs as `root:root` and reads its own `info.json`, so `0640` is safe; petclinic continued serving `HTTP/1.1 200` after the chmod and `smartagent.service` remained `active`.
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
- The brownfield JVM on `smartagent-1` does depend on `/etc/profile.d/set-appdynamics-env.sh` exporting `LD_PRELOAD=/opt/appdynamics/appdsmartagent/lib/libpreload.so` from a login shell. Always start petclinic via `bash -lc 'cd ~/spring-petclinic && nohup ./run-app.sh >/tmp/petclinic.log 2>&1 </dev/null &'` (or via interactive SSH, which itself runs a login shell). Do not paper over a libpreload regression with `_JAVA_OPTIONS=-javaagent:...` or `JAVA_TOOL_OPTIONS`; those mask the real attach path and skip Deployment Group system properties.
- `appdynamics-machine-agent.service` on `smartagent-3` previously emitted `PIDFile= references a path below legacy directory /var/run/, updating /var/run/appdynamics-machine-agent.pid → /run/appdynamics-machine-agent.pid; please update the unit file accordingly.` on every `daemon-reload`. The unit file at `/etc/systemd/system/appdynamics-machine-agent.service` was admin-installed (not `dpkg`-managed), so on April 28, 2026 it was edited in place to use `/run/appdynamics-machine-agent.pid` consistently (lines 34–36 changed from `/var/run` to `/run`), the executable mode bits were stripped to `0644`, and the service was restarted. `daemon-reload` is now silent for that unit. The pre-fix unit is preserved on the host as `appdynamics-machine-agent.service.bak.20260428T155720Z`.
- For backstage Windows hostname checks, prefer EC2 console output or System Properties over `$env:COMPUTERNAME`; Windows can expose a shortened 15-character form there.
- Do not use `smartagentctl status --remote` as a harmless read-only check on the current control host. During validation it stopped and synchronized remote Smart Agent services.
- Do not use `migrate --remote` from `26.3.0.938` as the rehearsed push path on already-enrolled hosts. With identical source and destination paths it can zero `config.ini` before the follow-up start step.
- `smartagent-4` is already enrolled, so it is not a true clean-target install demo unless it is reset first.
