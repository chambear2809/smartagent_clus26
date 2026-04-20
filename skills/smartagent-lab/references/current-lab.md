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

- The live control-host bundle in `~/appdsm` is still `26.2.0-779`.
- A staged `26.3.0-938` bundle exists on the control host in `/home/ubuntu/appdsm-26.3.0.938`.
- The rehearsed latest-bundle remote push path is `cd ~/appdsm-26.3.0.938 && sudo ./smartagentctl start --service --remote`.
- Managed Linux hosts now run Smart Agent `26.3.0-938` from `/opt/appdynamics/appdsmartagent`.
- The control host `remote.yaml` already follows the recommended demo pattern:
  - SSH login user `ubuntu`
  - `privileged: true`
  - managed-host Smart Agent runtime `root:root`
- The repo validation scripts now check that ownership model explicitly.
- The repo validation scripts now also gate on non-empty managed-host `config.ini` plus remote-push readiness for the SSH login user.
- For the current lab, `/opt/appdynamics/appdsmartagent` and `/opt/appdynamics/appdsmartagent/staging` on the managed Linux hosts must stay writable by `ubuntu` for latest-bundle remote push to work.
- The Java demo app is `~/spring-petclinic`.
- `smartagent-1` served `HTTP/1.1 200` on port `8080` after `run-app.sh`.
- `smartagent-2` has Node.js installed.
- `appdynamics-machine-agent.service` is stale and broken because `/opt/appdynamics/machine-agent/bin/machine-agent` is missing.

## Operational Warnings

- The stale `/etc/environment` preload export was removed on April 20, 2026.
- Fresh SSH logins to the control host should no longer arrive with `LD_PRELOAD` set.
- `/etc/profile.d/set-appdynamics-env.sh` still exists, but it is not actively enabling the preload in the current lab.
- Do not use `smartagentctl status --remote` as a harmless read-only check on the current control host. During validation it stopped and synchronized remote Smart Agent services.
- Do not use `migrate --remote` from `26.3.0.938` as the rehearsed push path on already-enrolled hosts. With identical source and destination paths it can zero `config.ini` before the follow-up start step.
- `smartagent-4` is already enrolled, so it is not a true clean-target install demo unless it is reset first.
