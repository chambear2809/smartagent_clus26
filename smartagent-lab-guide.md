# Smart Agent Demo Lab Guide

Last updated: April 22, 2026

## Repeatable Entry Point

Preferred operator workflow: use the repo-local `$smartagent-lab` skill in [skills/smartagent-lab](/Users/alecchamberlain/Documents/GitHub/smartagent_clus26/skills/smartagent-lab) with a copied lab profile, then use this guide as the human-readable walkthrough.

Before rehearsal, run the repo validator against the copied profile:

```bash
bash skills/smartagent-lab/scripts/validate_lab.sh --profile <copied-profile> --require-windows-demo
```

It now exits non-zero on critical demo drift. If `smartagent-3` is part of the live flow, add `--require-machine-agent`.

## Purpose

This runbook is the leave-behind for rebuilding and rehearsing the Smart Agent demo. It is written so another presenter can follow it without having the original presenter’s keys, passwords, or SaaS credentials. Use placeholders, then substitute your own access method and credentials.

This version is grounded in live validation of the current AWS lab in `us-east-1`.

## What Was Validated Live

- SSH access to the control node worked with the Linux user `ubuntu`.
- The Smart Agent launcher bundle is in `/home/ubuntu/appdsm`.
- The live control-node bundle in `~/appdsm` is version `26.2.0-779`.
- The staged latest bundle in `~/appdsm-26.3.0.938` was validated for remote rollout with `sudo ./smartagentctl start --service --remote`.
- The control node local Smart Agent could be started successfully with `sudo ./smartagentctl start --service`.
- `smartagent-1`, `smartagent-2`, `smartagent-3`, and `smartagent-4` now run Smart Agent `26.3.0-938`.
- `smartagent-1` successfully started `~/spring-petclinic/run-app.sh` and served `HTTP 200` on `8080`.
- `smartagent-1` now has a minimal same-host `splunk-otel-collector` service installed and healthy on `127.0.0.1:13133`, `127.0.0.1:4317`, and `127.0.0.1:4318`.
- `smartagent-2` had Node.js installed and returned `v22.22.0`.
- `smartagent-2` also had `~/weather-app/src` staged, and `node server.js` was listening on `3000`.
- The live `node server.js` process on `smartagent-2` was starting with Smart Agent `LD_PRELOAD`, loading the AppDynamics Node native modules, and establishing controller connectivity.
- The live Node agent log showed node registration plus BT `/` registration for `weather-app`.
- `smartagent-3` now has a repaired `appdynamics-machine-agent.service`, and the infra path passes `validate_lab.sh --require-machine-agent`.
- The Windows host is intentionally pinned at Smart Agent `26.2.0-779` so the opening UI move can upgrade it to `26.3.0-938`.

## What Was Not Validated Live

- A true first-time Smart Agent install onto a clean Linux host
- The archive-based collector fallback on a restricted-egress managed Linux host
- A Node.js app sending dual-signal data to Splunk Observability Cloud
- A final visual rehearsal of the exact Windows upgrade click path in the current AppDynamics tenant

Why:

- `smartagent-4` is already enrolled and running Smart Agent.
- The canonical local-collector path is now the installer-based helper on `smartagent-1`; the archive path remains a contingency workflow.
- `Smartagent-windows-1` is intentionally kept at `26.2.0-779`, but the final `Agent Management > Smart Agents > Upgrade` click-through should still be rehearsed in the live tenant before demo day.
- `smartagent-2` has a staged Node.js app and AppDynamics auto-attach proof, but the dual-signal OTel path is still not rehearsed live.
- The current latest-bundle remote rollout needs `/opt/appdynamics/appdsmartagent` and `/opt/appdynamics/appdsmartagent/staging` to stay writable by the SSH login user `ubuntu`.

## What This Guide Covers

- Control-node preparation
- Smart Agent configuration and lifecycle explanation
- Windows-first host upgrade through Agent Management
- Java brownfield demo using `~/spring-petclinic`
- Optional Node.js path
- Machine Agent repair and infrastructure validation on `smartagent-3`
- A safe way to talk about remote lifecycle control in this exact lab

## Inputs You Must Supply

| Item | Notes |
| --- | --- |
| SSH access to the EC2 hosts | Use your own key or password method |
| AppDynamics Controller URL | Example: `customer.saas.appdynamics.com` |
| AppDynamics account name | For Smart Agent controller config |
| AppDynamics access key | For controller auth |
| Splunk Observability Cloud realm | Example: `us1` |
| Splunk Observability Cloud access token | For the local collector O11y export path and the direct-to-Splunk OTLP variant |

Optional fallback input:

- Local collector archive for Linux AMD64, only if the Java host lacks outbound egress and you cannot use the installer helper

Optional operator environment variables:

- `SMARTAGENT_CONTROL_SSH_PASSWORD` for password auth from your workstation to the control host
- `SMARTAGENT_MANAGED_SSH_PASSWORD` for password auth from the control host to managed hosts

A reusable template lives at [smartagent-lab-credentials.example.env](/Users/alecchamberlain/Documents/GitHub/smartagent_clus26/smartagent-lab-credentials.example.env). Copy it to a filled-in `smartagent-lab-credentials.env`, keep that filled-in file outside the repo or untracked, and source it in the shell that will run the demo commands.

## Known Lab Inventory

| Host | Address Source | Validated Use |
| --- | --- | --- |
| `smartagentctl-base` | control-host address from the copied lab profile | Control node and launcher host |
| `smartagent-1` | private VPC IP from the copied lab profile | Java `~/spring-petclinic` host |
| `smartagent-2` | private VPC IP from the copied lab profile | Optional Node.js host |
| `smartagent-3` | private VPC IP from the copied lab profile | Infrastructure host after Machine Agent repair and validation |
| `smartagent-4` | private VPC IP from the copied lab profile | Reset/reinstall target if needed |
| `Smartagent-windows-1` | address from the copied lab profile | Windows host for the opening Agent Management upgrade story |

Refresh before every demo:

```bash
aws ec2 describe-instances \
  --region us-east-1 \
  --filters Name=tag:Name,Values='smartagent-*','Smartagent-*' Name=instance-state-name,Values=running \
  --query 'Reservations[].Instances[].{Name:Tags[?Key==`Name`]|[0].Value,PrivateIp:PrivateIpAddress,PublicIp:PublicIpAddress,Image:ImageId}' \
  --output table
```

## 1. Connect To The Control Node

Use whatever SSH access method your lab supports:

```bash
ssh <ssh-options> <ssh-user>@<control-node-public-ip>
```

Current-lab note:

- Look up the active control-host address from the copied lab profile or [current-lab.md](/Users/alecchamberlain/Documents/GitHub/smartagent_clus26/skills/smartagent-lab/references/current-lab.md) before the session.

Managed-host rule:

- Do not work directly against the managed hosts by public IP for the repeatable lab workflow.
- Use the control host as the operator entry point.
- From the control host, reach the managed hosts by their private VPC IPs.

## 2. Validate The Control Host Environment

The durable control-host fix is already applied. Fresh SSH logins should now be clean.

```bash
env | grep '^LD_PRELOAD=' || true
```

Expected result:

- no output on a brand-new SSH login

Validated live note:

- the stale `/etc/environment` export was removed during live validation
- `/etc/profile.d/set-appdynamics-env.sh` still exists, but it is not actively enabling the preload in the current lab

Fallback for an older reused shell:

- `unset LD_PRELOAD` in the current shell

## 3. Prepare Smart Agent On The Control Node

The validated launcher bundle location is:

```bash
cd ~/appdsm
```

Instead of retyping secrets by hand, copy the template in this repo to a filled-in local file. The shell that runs `smartagentctl` must source it. For the control-node workflow in this guide, either create the filled-in file directly on the control node or copy it there first:

```bash
cp /path/to/smartagent-lab-credentials.example.env /secure/path/smartagent-lab-credentials.env
$EDITOR /secure/path/smartagent-lab-credentials.env
scp <ssh-options> /secure/path/smartagent-lab-credentials.env <ssh-user>@<control-node-public-ip>:~/smartagent-lab-credentials.env
ssh <ssh-options> <ssh-user>@<control-node-public-ip>
source ~/smartagent-lab-credentials.env
cd ~/appdsm
```

The template sets these variables:

```bash
export SUPERVISOR_CONTROLLER_URL=<your-controller-url>
export SUPERVISOR_CONTROLLER_PORT=443
export SUPERVISOR_ACCOUNT_NAME=<your-account-name>
export SUPERVISOR_ACCOUNT_ACCESS_KEY=<your-account-access-key>
export SUPERVISOR_ENABLE_SSL=true
export SPLUNK_REALM=<your-splunk-realm>
export SPLUNK_ACCESS_TOKEN=<your-splunk-access-token>
```

Portable `config.ini` pattern:

```ini
[controller]
ControllerURL = ${env:SUPERVISOR_CONTROLLER_URL}
ControllerPort = ${env:SUPERVISOR_CONTROLLER_PORT:-443}
AccountName = ${env:SUPERVISOR_ACCOUNT_NAME}
AccountAccessKey = ${env:SUPERVISOR_ACCOUNT_ACCESS_KEY}
EnableSSL = ${env:SUPERVISOR_ENABLE_SSL:-true}
```

Why teach it this way:

- the file stays stable
- the environment changes between labs
- it makes the naming convention visible to the audience

## 4. Start Local Smart Agent On The Control Node

```bash
cd ~/appdsm
sudo ./smartagentctl start --service
sudo ./smartagentctl status
```

Validated live result:

- Smart Agent started successfully
- `status` returned `Running`

## 5. Understand The Current Remote Lifecycle Model

The control node already has a `remote.yaml` that targets all four Linux managed hosts.

Generic pattern:

```yaml
max_concurrency: 4
remote_dir: /opt/appdynamics/appdsmartagent
protocol:
  type: ssh
  auth:
    username: <ssh-user>
    private_key_path: /home/<ssh-user>/.ssh/<lab-key>.pem
    privileged: true
    ignore_host_key_validation: true
    known_hosts_path: /home/<ssh-user>/.ssh/known_hosts
hosts:
  - host: "<target-private-ip>"
    port: 22
    user: root
    group: root
```

What this means:

- `protocol.auth.username` is the SSH login user, not the Smart Agent service user.
- `privileged: true` allows Smart Agent to escalate and install a system-wide service.
- `hosts[].user` and `hosts[].group` define the runtime identity of the Smart Agent service on the managed host.
- The repo validation script now checks this model directly against `remote.yaml` and `systemd`.

Recommended demo pattern:

- Use a normal SSH login user such as `ubuntu` or `ec2-user`
- Keep `privileged: true`
- Keep the managed-host Smart Agent runtime as `root:root`
- Avoid direct root SSH as the primary presenter workflow

Why this lab uses `root:root`:

- It gives one repeatable profile that can cover the broadest agent set.
- Java and Node.js can run as any user, but Machine, Apache, Python, and PHP default to `root:root`.
- This is a demo simplification for breadth, not least-privilege production guidance.

Validated live note:

- The actual file lives at `~/appdsm/remote.yaml`
- The current target hosts are the private-IP values from the copied lab profile
- The live file already uses `username: ubuntu`, `privileged: true`, and `user: root` / `group: root`

## 6. Important Warning About `--remote`

Do not treat this as a harmless read-only check:

```bash
sudo ./smartagentctl status --remote
```

During live validation on `26.2.0-779`, it:

- connected to the remote Linux hosts
- ran remote status
- stopped remote Smart Agent services
- performed synchronization behavior

This means you should use one of these instead during a live demo:

- Agent Management UI
- direct `systemctl status smartagent` on one target host
- a deliberately rehearsed remote lifecycle action

Validated latest-bundle rollout path for the current brownfield lab:

```bash
cd ~/appdsm-26.3.0.938
sudo ./smartagentctl start --service --remote
```

Do not use this on already-enrolled hosts:

```bash
cd ~/appdsm-26.3.0.938
sudo ./smartagentctl migrate --remote --src-dir /opt/appdynamics/appdsmartagent
```

During live validation it left the managed-host `config.ini` empty because the source and destination paths were identical.

## 7. If You Need A True First-Install Story

The current lab is already enrolled, so prepare that story intentionally:

1. Launch a brand-new Linux host in the same VPC, or
2. Reset one target during rehearsal, or
3. Clone a clean image without `/opt/appdynamics/appdsmartagent`

Then the live remote command can honestly be:

```bash
cd ~/appdsm
sudo ./smartagentctl start --enable-auto-attach --service --remote
```

## 8. Validate Agent Management

In AppDynamics SaaS:

1. Open Agent Management.
2. Confirm the managed Linux hosts are visible.
3. Confirm `Smartagent-windows-1` is visible in `Smart Agents` and still shows Smart Agent `26.2.0-779` before the live upgrade.
4. If you started local Smart Agent on the control node, confirm it also appears as expected.
5. Use this moment to explain lifecycle, versioning, and rollout posture.

## 8A. Windows Host Upgrade Through Agent Management

Use this path to open the demo with a Smart Agent version upgrade without turning the demo into a remote desktop session.

Rehearsal prerequisites:

- `Smartagent-windows-1` must already be enrolled and visible in `Agent Management > Smart Agents`.
- The host label and the Windows OS hostname should both read `Smartagent-windows-1`.
- The current Windows Smart Agent version should still be `26.2.0-779`.
- The target upgrade version should be `26.3.0-938`, or whatever newer release you plan to show.
- Windows and Linux Smart Agent packages are different. Do not point the Linux bundle or the Linux remote-rollout path at this host.

Live UI flow:

1. Open `Agent Management > Smart Agents`.
2. Filter to `Smartagent-windows-1`.
3. Confirm the current Smart Agent version is `26.2.0-779`.
4. Click `Upgrade`.
5. Select `26.3.0-938` as the target version and use the rehearsed upgrade option.
6. Watch the deployment status until the upgrade is clearly in progress or complete.
7. Use the resulting version change as the proof point.

Talk track:

- “This is the Windows proof point. The lifecycle change is coming from Agent Management, not from an RDP session.”
- “I intentionally kept this host one version back, so the first live move is a visible upgrade, not a theoretical admin screen.”

Backup proof:

- Keep a rehearsed PowerShell, Services, `smartagentctl.exe version`, or EC2 console-output check available backstage if someone asks for host-side confirmation.
- Prefer System Properties or EC2Launch console output over `$env:COMPUTERNAME` if you need the full Windows hostname; Windows can expose a shortened 15-character form there.
- Let the UI remain the primary live proof unless the room explicitly asks for deeper host evidence.

## 9. Java Demo On `smartagent-1` Using `~/spring-petclinic`

Connect:

```bash
ssh <ssh-options> <ssh-user>@<control-node-public-ip>
ssh <managed-ssh-options> <managed-ssh-user>@<java-demo-private-ip>
```

Inspect the existing brownfield app:

```bash
cd ~/spring-petclinic
find . -maxdepth 2 \( -name pom.xml -o -name '*.jar' \)
sed -n '1,20p' run-app.sh
```

Current-lab reminder:

- keep `run-app.sh` plain for the demo instead of injecting `JAVA_TOOL_OPTIONS` there
- use the host's normal login-shell path when rehearsing, because this lab exports Smart Agent auto-attach through `/etc/profile.d/set-appdynamics-env.sh`

Validated live startup path:

```bash
cd ~/spring-petclinic
nohup ./run-app.sh >/tmp/petclinic.log 2>&1 < /dev/null &
sleep 8
ss -ltnp | grep 8080
curl -sfI http://127.0.0.1:8080
tail -n 20 /tmp/petclinic.log
```

Validated live result:

- Java bound to `*:8080`
- `curl -I` returned `HTTP/1.1 200`

## 10. Java Combined-Mode Environment

Teach these mode values:

- `AGENT_DEPLOYMENT_MODE=appdynamics`
- `AGENT_DEPLOYMENT_MODE=dual`
- `AGENT_DEPLOYMENT_MODE=otel`

Current-lab reality:

- `smartagent-1` now has a minimal same-host local collector installed and healthy
- if you want install motion, rerun the repo helper on `smartagent-1` and narrate that it is idempotent
- if you do not want that extra motion live, use the direct-to-Splunk variant instead

### 10A. Local Collector On `smartagent-1`

The latest Splunk AppDynamics docs say:

- in most cases, run an OpenTelemetry collector on the same system as the Java Agent
- the recommended package is the Cisco AppDynamics Distribution for OpenTelemetry Collector
- for this repo, prefer the installer-based helper because it is now idempotent and rewrites the host to a minimal local-collector config for O11y forwarding
- in dual mode, the Java Combined Agent still sends AppDynamics APM data to the Controller directly
- the local collector is for the OpenTelemetry side and should forward to Splunk Observability Cloud

Demo recommendation:

- use the repo helper with `--use-splunk-installer` as the canonical path when the host has network egress
- rerunning the helper is safe because it reuses the package and refreshes the minimal collector config
- keep the archive workflow as a restricted-network fallback only
- verify an active `splunk-otel-collector` service, a healthy check on `127.0.0.1:13133`, and listeners on `4317` or `4318`
- then apply the Deployment Group dual-mode policy and restart the JVM

Repeatable repo helper:

```bash
bash skills/smartagent-lab/scripts/install_local_collector.sh \
  --profile <copied-profile> \
  --use-splunk-installer \
  --execute
```

Restricted-egress fallback:

```bash
bash skills/smartagent-lab/scripts/install_local_collector.sh \
  --profile <copied-profile> \
  --archive <local-collector-archive> \
  --execute
```

Expected result:

- the collector service is active
- the health check on `127.0.0.1:13133` responds
- `4317` and or `4318` are listening on `smartagent-1`
- there are no recent collector export errors

### 10B. Local Collector Dual-Mode Switch

Once the collector is running locally, the minimal switch is:

```bash
export AGENT_DEPLOYMENT_MODE=dual
```

The runtime JVM property is:

```text
-Dagent.deployment.mode=dual
```

In Agent Management `java_system_properties`, enter the raw `key=value` form without the `-D` prefix:

```text
agent.deployment.mode=dual
```

Or in Deployment Group Java custom configuration:

```yaml
install_agent_from: appd-portal
user: ubuntu
group: ubuntu
java_system_properties: "agent.deployment.mode=dual"
```

If you are editing only the UI field, paste `agent.deployment.mode=dual` without extra outer quotes in the field.

UI behavior note:

- enter raw values in the custom-configuration field and let the UI normalize the rendering
- one layer of quotes in the rendered view is usually harmless
- doubled quotes usually mean the value was pasted with quotes and then quoted again by the UI

Host-side verification gate before the JVM restart:

- check `/opt/appdynamics/appdsmartagent/profile/java/.manage/info.json`
- in the current lab, a clean Deployment Group shows `java_system_properties:"agent.deployment.mode=dual ..."` there
- trust `info.json` over the rendered UI text when you need to know what reached the host
- use that check to prove the Deployment Group reached the host before you restart the brownfield JVM and inspect the live process

If the Deployment Group UI and the host do not seem to agree:

- inspect `/opt/appdynamics/appdsmartagent/log.log`
- search for `Attempting to update remote config`
- inspect the `auto_attach` payload the host actually received
- in the current lab, that payload expresses Java auto-attach as `agentProperties.agent_dir="./profile/java"`

Operational caveat:

- the current docs say dynamic attachment is not supported when OpenTelemetry is enabled
- apply the Deployment Group before the JVM starts, or restart the JVM after the change
- AppDynamics APM data still goes straight to the Controller from the Combined Agent; the collector is only for the O11y side
- in the current lab, auto-attach is surfaced through `/etc/profile.d/set-appdynamics-env.sh`, so use a normal login-shell start path when you rehearse the brownfield app
- keep `run-app.sh` plain in the demo; hand-editing `JAVA_TOOL_OPTIONS` there can hide a broken Deployment Group config

If the collector endpoint is not the default local listener, make it explicit:

```yaml
install_agent_from: appd-portal
user: ubuntu
group: ubuntu
java_system_properties: "agent.deployment.mode=dual otel.exporter.otlp.endpoint=http://127.0.0.1:4318 otel.exporter.otlp.protocol=http/protobuf otel.service.name=petclinic otel.resource.attributes=service.namespace=smartagent-demo,deployment.environment.name=fso-tme,host.name=smartagent-1 otel.metrics.exporter=none otel.logs.exporter=none"
```

Formatting reminder:

- do not include leading `-D` in `java_system_properties`
- do not wrap the whole UI field in doubled outer quotes
- type raw values in the UI and let the renderer add a single quote layer if it wants to

Rehearsal gate:

```bash
bash skills/smartagent-lab/scripts/validate_lab.sh --profile <copied-profile> --require-java-collector
```

### 10C. Direct-To-Splunk Fallback Variant

If you deliberately skip the local collector during the live session, this is the direct-export variant:

```bash
export AGENT_DEPLOYMENT_MODE=dual
export OTEL_SERVICE_NAME=petclinic
export OTEL_RESOURCE_ATTRIBUTES=service.namespace=smartagent-demo,deployment.environment.name=aws-lab,host.name=smartagent-1
export OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
export OTEL_EXPORTER_OTLP_ENDPOINT=https://ingest.${SPLUNK_REALM}.observability.splunkcloud.com/v2/trace/otlp
export OTEL_EXPORTER_OTLP_HEADERS=x-sf-token=${SPLUNK_ACCESS_TOKEN}
export OTEL_LOGS_EXPORTER=none
```

Restart method:

- if the app is launched directly from the home directory, export the variables in the same shell before `run-app.sh`
- if you later convert it into a service, place the values in the service environment

## 11. Optional Node.js Demo On `smartagent-2`

Validated live facts:

- `smartagent-2` has Node.js installed
- `node -v` returned `v22.22.0`
- `~/weather-app/src` is staged on the host
- `node server.js` is listening on `3000`
- the running process carries Smart Agent `LD_PRELOAD`
- the live Node agent log shows controller connectivity, node registration, and BT `/` registration

Only use the Node path if you keep the current app state intact or revalidate it before the presentation.

Generic staging pattern:

```bash
scp <ssh-options> -r <local-node-demo-dir> <ssh-user>@<control-node-public-ip>:~/
ssh <ssh-options> <ssh-user>@<control-node-public-ip>
scp -r <local-node-demo-dir> <managed-ssh-user>@<node-demo-private-ip>:~/
ssh <managed-ssh-options> <managed-ssh-user>@<node-demo-private-ip>
cd ~/weather-app/src
npm install
```

Optional combined-mode block:

```bash
export AGENT_DEPLOYMENT_MODE=dual
export OTEL_SERVICE_NAME=weather-app
export OTEL_RESOURCE_ATTRIBUTES=service.namespace=smartagent-demo,deployment.environment.name=aws-lab,host.name=smartagent-2
export OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
export OTEL_EXPORTER_OTLP_ENDPOINT=https://ingest.${SPLUNK_REALM}.observability.splunkcloud.com/v2/trace/otlp
export OTEL_EXPORTER_OTLP_HEADERS=x-sf-token=${SPLUNK_ACCESS_TOKEN}
npm start
```

## 12. Machine Agent Path On `smartagent-3`

Current live state:

- `appdynamics-machine-agent.service` is active
- `/opt/appdynamics/machine-agent/bin/machine-agent` exists
- the path now passes `bash skills/smartagent-lab/scripts/validate_lab.sh --profile <copied-profile> --require-machine-agent`

Steady state to preserve before demo day:

- keep `appdynamics-machine-agent.service` active
- confirm the host is visible in the AppDynamics infrastructure view you plan to show
- confirm any paired Splunk O11y infrastructure view is also ready if that is part of the story
- run `bash skills/smartagent-lab/scripts/validate_lab.sh --profile <copied-profile> --require-machine-agent`

Useful host-side verification:

```bash
systemctl status appdynamics-machine-agent --no-pager -l
test -x /opt/appdynamics/machine-agent/bin/machine-agent && echo "machine_agent_binary=yes"
journalctl -u appdynamics-machine-agent --since '-5 min' --no-pager | tail -n 20
```

Presenter line:

- “This closes the loop. The same Smart Agent operating model now covers infrastructure visibility as well as app lifecycle.”

## 13. Rehearsal Checklist

- Confirm all Linux hosts are running in `us-east-1`
- Refresh public IPs
- Confirm the control node can reach the managed nodes by private IP
- Confirm a fresh control-host login does not carry `LD_PRELOAD`
- Confirm Agent Management access
- Run `bash skills/smartagent-lab/scripts/validate_lab.sh --profile <copied-profile> --require-windows-demo`
- Confirm `Smartagent-windows-1` is visible in `Agent Management > Smart Agents`, is still on `26.2.0-779`, and is ready to upgrade to `26.3.0-938`
- Confirm `~/spring-petclinic` on `smartagent-1` starts and returns `HTTP 200`
- Load Splunk realm and access token before any dual-signal restart
- If you want a first-install story, prepare a clean host in rehearsal
- If you want an infrastructure story, repair Machine Agent first and run the validator with `--require-machine-agent`
- Capture screenshots of UI checkpoints as backup

## 14. Safe Demo Mode

1. Open `Agent Management > Smart Agents` and confirm `Smartagent-windows-1` is still on `26.2.0-779`.
2. Run the rehearsed Windows upgrade to `26.3.0-938` and leave the UI showing rollout status.
3. Pivot to the control node, show `config.ini`, and explain `SUPERVISOR_*`.
4. Show `remote.yaml` and the existing managed-host list.
5. Start `~/spring-petclinic` on `smartagent-1` and validate `HTTP 200`.
6. Explain `AGENT_DEPLOYMENT_MODE` and dual-signal behavior.
7. Show `smartagent-3` only after the validator passes with `--require-machine-agent`.
8. Skip Node unless pre-staged.

## 15. Rollback Notes

- To return Java to AppDynamics-only behavior, set `AGENT_DEPLOYMENT_MODE=appdynamics` and restart the app
- To remove the optional Node demo, stop the Node process and leave Smart Agent in place
- If you prepared a reset target for a first-install story, restore it after the session

## Reference Docs

- Install Smart Agent: https://help.splunk.com/en/appdynamics-saas/agent-management/26.4.0/smart-agent/get-started/install-smart-agent
- Configure Smart Agent: https://help.splunk.com/en/appdynamics-saas/agent-management/26.4.0/smart-agent/get-started/configure-smart-agent
- Upgrade Smart Agent: https://help.splunk.com/en/appdynamics-on-premises/agent-management/26.3.0/smart-agent/upgrade-smart-agent
- Auto-Attach Java and NodeJS Agents: https://help.splunk.com/en/appdynamics-saas/agent-management/26.4.0/smart-agent/auto-attach-java-and-nodejs-agents
- SSH Configuration for Remote Host: https://help.splunk.com/en/appdynamics-on-premises/agent-management/26.4.0/smart-agent/manage-the-agents-using-smartagentctl/install-supported-agents-using-smartagentctl/ssh-configuration-for-remote-host
- Monitor Applications with Combined Agent: https://help.splunk.com/en/appdynamics-saas/application-performance-monitoring/26.2.0/splunk-appdynamics-for-opentelemetry/instrument-applications-with-splunk-appdynamics-for-opentelemetry/monitor-applications-with-combined-agent
- Enable Dual Signal Mode for Java: https://help.splunk.com/en/appdynamics-saas/application-performance-monitoring/26.4.0/splunk-appdynamics-for-opentelemetry/instrument-applications-with-splunk-appdynamics-for-opentelemetry/enable-opentelemetry-in-the-java-agent/enable-dual-signal-mode
- Dual Signal Mode for Node.js Combined Agent: https://help.splunk.com/en/appdynamics-on-premises/application-performance-monitoring/26.3.0/splunk-appdynamics-for-opentelemetry/instrument-applications-with-splunk-appdynamics-for-opentelemetry/enable-opentelemetry-in-the-node.js-agent/dual-signal-mode-for-node.js-combined-agent
- Combined Agent for Infrastructure Visibility: https://help.splunk.com/en/appdynamics-on-premises/infrastructure-visibility/26.3.0/machine-agent/combined-agent-for-infrastructure-visibility
- Agent Enhancements 26.2.0: https://help.splunk.com/en/appdynamics-saas/release-notes-and-references/agents-release-notes/26.2.0/agent-enhancements
