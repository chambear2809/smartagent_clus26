# Smart Agent 45-Minute Demo Script

Last updated: April 22, 2026

## Repeatable Entry Point

Preferred operator workflow: use the repo-local `$smartagent-lab` skill in [skills/smartagent-lab](/Users/alecchamberlain/Documents/GitHub/smartagent_clus26/skills/smartagent-lab) with a lab profile before following the live script. The skill is built around a public control host plus private-VPC managed targets.

Use the validator before rehearsal:

```bash
bash skills/smartagent-lab/scripts/validate_lab.sh --profile <copied-profile> --require-windows-demo
```

It exits non-zero on critical demo drift. If `smartagent-3` is part of the live flow, add `--require-machine-agent`.

## Goal

Show Splunk AppDynamics Smart Agent as the lifecycle control plane for a mixed estate, then show how that same estate can move into OpenTelemetry and Splunk Observability Cloud without throwing away AppDynamics value. The live story should now open with a Windows Smart Agent upgrade in Agent Management and include a repaired Machine Agent path on `smartagent-3`.

## What Was Validated Live

- The control node is reachable and the Smart Agent launcher bundle is in `/home/ubuntu/appdsm`.
- The live control-node bundle in `~/appdsm` is version `26.2.0-779`.
- The staged latest bundle in `~/appdsm-26.3.0.938` was validated for remote rollout with `sudo ./smartagentctl start --service --remote`.
- The control node local `smartagent.service` was initially stopped, and `sudo ./smartagentctl start --service` started it successfully.
- `smartagent-1`, `smartagent-2`, `smartagent-3`, and `smartagent-4` now run Smart Agent `26.3.0-938` from `/opt/appdynamics/appdsmartagent`.
- The Java app path is `~/spring-petclinic`, not `~/petclinic`.
- On `smartagent-1`, `~/spring-petclinic/run-app.sh` started cleanly and served `HTTP/1.1 200` on port `8080`.
- `run-app.sh` on `smartagent-1` is a plain `java -jar` launch. There is no hand-managed `-javaagent` in the app start script.
- Smart Agent auto-discovery is active on the managed Linux hosts, and the Java profile includes the Combined Agent OTel libraries and config scaffolding.
- `smartagent-1` now has a same-host `splunk-otel-collector` service installed with healthy listeners on `127.0.0.1:4317` and `127.0.0.1:4318`, plus a passing health check on `127.0.0.1:13133`.
- `smartagent-2` has Node.js installed and returned `v22.22.0`.
- `smartagent-2` also has `~/weather-app/src`, and `node server.js` is listening on `3000`.
- The live `node server.js` process on `smartagent-2` is starting with Smart Agent `LD_PRELOAD`, loading the AppDynamics Node native modules, and maintaining controller connectivity.
- The live Node agent log shows node registration plus BT `/` registration for `weather-app`.
- `smartagent-3` now has a repaired `appdynamics-machine-agent.service`. The Machine Agent has been active continuously since April 24, 2026.
- The Windows host is intentionally pinned at `26.2.0-779` so the opening UI move can upgrade it to `26.3.0-938`.

## Important Live Caveats

- For this exact lab, the honest story is brownfield lifecycle control, not first-ever Smart Agent installation. The Linux managed hosts are already enrolled.
- If you want a “fresh install” moment, prepare a new Linux host or deliberately reset a target during rehearsal.
- The opening move is the Windows Smart Agent upgrade in `Agent Management > Smart Agents`. Keep `Smartagent-windows-1` on `26.2.0-779` until the session starts.
- `validate_lab.sh --require-windows-demo` pins the Windows host label, expected hostname, and current or target versions, but you should still do one final visual rehearsal of the UI click path before demo day.
- Windows and Linux Smart Agent packages are different. Do not use the Linux bundle or Linux remote-rollout path against the Windows host.
- For Java dual mode with a local collector, the collector is a separate OpenTelemetry Collector process on the same host as the Java runtime. It is not the Machine Agent.
- The current lab already has a minimal same-host collector on `smartagent-1`. If you want the install motion on stage, rerun the repo helper and narrate that it is idempotent.
- `smartagentctl status --remote` is not safe to present as a harmless read-only check on this `26.2.0-779` control node. During validation it stopped and synchronized remote Smart Agent services.
- For the current latest-bundle rollout, `/opt/appdynamics/appdsmartagent` and `/opt/appdynamics/appdsmartagent/staging` on the managed Linux hosts must stay writable by the SSH login user `ubuntu`. **Validated live April 28, 2026:** all four managed hosts (`smartagent-1`, `smartagent-2`, `smartagent-3`, `smartagent-4`) are at `root:ubuntu 775` on both paths and pass the `validate_lab.sh` writability check. If a host drifts again, re-run `bash skills/smartagent-lab/scripts/prepare_remote_push.sh --profile <copied-profile> --execute`; the script iterates every managed host in the profile and is idempotent on already-writable hosts.
- Do not rehearse `migrate --remote` on already-enrolled hosts with `26.3.0.938`; it can zero the managed-host `config.ini`.
- Do not put `smartagent-3` on stage unless `validate_lab.sh --require-machine-agent` passes on the current day.
- The durable control-host `LD_PRELOAD` fix is already applied. Fresh SSH logins should now be clean.

## Audience Message

- Operations teams get centralized rollout, upgrade, and attach control.
- Application teams keep AppDynamics concepts while adding OpenTelemetry signals.
- Platform teams standardize on environment-variable naming instead of host-specific snowflake config, and they can tell the same lifecycle story across Linux and Windows.

## Validated Lab Inventory

Private VPC IPs are the primary live addresses for the demo. Public or bastion entry details belong in the copied lab profile or in [current-lab.md](/Users/alecchamberlain/Documents/GitHub/smartagent_clus26/skills/smartagent-lab/references/current-lab.md), not in the generic talk track.

| Host | Instance ID | OS | Address Source | Role In Demo |
| --- | --- | --- | --- | --- |
| `smartagentctl-base` | `i-046e9fb473d39d9bc` | Ubuntu 22.04 | control-host address from the copied lab profile | Launcher host, Smart Agent bundle in `~/appdsm` |
| `smartagent-1` | `i-0af7f834c3c25e189` | Ubuntu 22.04 | private VPC IP from the copied lab profile | Primary Java brownfield host with `~/spring-petclinic` |
| `smartagent-2` | `i-0e1108e2654c3da61` | Ubuntu 22.04 | private VPC IP from the copied lab profile | Optional Node.js host |
| `smartagent-3` | `i-0b95f120775a511d3` | Ubuntu 24.04 | private VPC IP from the copied lab profile | Repaired Machine Agent host for infrastructure visibility once validated |
| `smartagent-4` | `i-0c077b933a1e0353b` | Ubuntu 24.04 | private VPC IP from the copied lab profile | Reset/reinstall target if you want a first-install rehearsal |
| `Smartagent-windows-1` | `i-0d9d7fdee7998d8ab` | Windows | address from the copied lab profile | Opening Agent Management upgrade host |

## Access Model

Do not publish personal keys or passwords in the leave-behind. Use placeholders and substitute the credential method available in your environment.

Generic SSH pattern:

```bash
ssh <ssh-options> <ssh-user>@<control-node-public-ip>
```

Validated lab note:

- The Linux username used during live validation was `ubuntu`.
- Use public access only for the control host. Reach managed hosts by private VPC IP from the control host.
- If you need password auth from the control host to managed hosts, the repo skill now supports `SMARTAGENT_MANAGED_SSH_PASSWORD`.

## Control Host Login Check

Fresh SSH logins to the control node should now be clean:

```bash
ssh <ssh-options> <ssh-user>@<control-node-public-ip>
```

If you are reusing an older shell that predates the fix, use this fallback:

```bash
unset LD_PRELOAD
```

Validated live note:

- The stale `/etc/environment` export was removed during live validation
- A brand-new SSH login no longer arrives with `LD_PRELOAD` set
- `/etc/profile.d/set-appdynamics-env.sh` still exists, but it is not actively enabling the preload in the current lab

## Run Of Show

| Time | Operator Action | Talk Track | Proof Point |
| --- | --- | --- | --- |
| `0:00-3:00` | Open the architecture diagram. | “This is a controlled EC2 lab, but the operating model is general: one launcher host, many managed hosts, AppDynamics on one side, Splunk O11y on the other.” | Establishes control plane and data plane. |
| `3:00-6:00` | Set the problem statement. | “The hard part is not agent capability. It is agent drift, configuration drift, and brownfield sprawl.” | Frames the demo as an operator problem. |
| `6:00-12:00` | Move to `Agent Management > Smart Agents`, filter to `Smartagent-windows-1`, confirm it is on `26.2.0-779`, and kick off the upgrade to `26.3.0-938`. | “I kept this host one version back on purpose. The first live move is a visible upgrade from the product UI, not a backstage server login.” | Opens with UI-driven lifecycle control on a Windows host. |
| `12:00-16:00` | SSH to `smartagentctl-base` and open `config.ini`. | “While that upgrade runs, notice the naming convention. `SUPERVISOR_*` gives you portable controller configuration.” | Shows platform configuration while the Windows rollout progresses. |
| `16:00-20:00` | Show `remote.yaml`, the managed target list, and the user/group model. If local Smart Agent is stopped, start it. | “In this lab the Linux nodes are already enrolled, so the honest proof is lifecycle control and synchronization. Also notice the identity split: SSH user, privilege escalation, and Smart Agent runtime user are different decisions.” | Keeps the narrative aligned with the actual lab state and explains the permission model clearly. |
| `20:00-26:00` | SSH to `smartagent-1`, show `~/spring-petclinic`, start it, and validate `HTTP 200`. | “This is the brownfield attach story. The app is already on the box. I’m not rebuilding it. I’m making an existing workload observable.” | Live-validated Java app startup on port `8080`. |
| `26:00-32:00` | On `smartagent-1`, verify the local collector or rerun the idempotent installer helper if you want to show the install motion, then show the Java Deployment Group settings for auto-attach and explain `AGENT_DEPLOYMENT_MODE`. | “The migration pivot is not a code rewrite. The app still starts normally. This host already has the collector path prepared, and the same helper can reapply it safely. The policy then decides the behavior.” | Shows that no manual `-javaagent` is needed, that the collector is separate from Machine Agent, and that dual mode is controlled by Java system properties. |
| `32:00-36:00` | Show `smartagent-3` with the repaired Machine Agent service and verify the infrastructure view. | “This closes the loop: the same operating model can cover infrastructure visibility once the host is repaired and validated.” | Turns infra visibility into a first-class proof point instead of an appendix apology. |
| `36:00-39:00` | Optional: show that `smartagent-2` has Node.js and only run Node if the app is already staged. | “Node follows the same model, but only put it on stage if the app is prepared before the session.” | Reinforces cross-runtime consistency without creating dead air. |
| `39:00-45:00` | Close with release improvements, rollout guardrails, and Q&A. | “The message is central lifecycle control, clean naming, brownfield attach, a visible Windows upgrade, and a controlled path to OpenTelemetry.” | Reinforces the operating model. |

## Command Blocks

### 1. Control Node Login

```bash
ssh <ssh-options> <ssh-user>@<control-node-public-ip>
cd ~/appdsm
```

Current-lab note:

- Look up the active control-host address from the copied lab profile or [current-lab.md](/Users/alecchamberlain/Documents/GitHub/smartagent_clus26/skills/smartagent-lab/references/current-lab.md) before the session.

### 2. Show Smart Agent Config Naming

```bash
grep -n 'SUPERVISOR_' config.ini
```

Portable example to discuss:

```ini
[controller]
ControllerURL = ${env:SUPERVISOR_CONTROLLER_URL}
ControllerPort = ${env:SUPERVISOR_CONTROLLER_PORT:-443}
AccountName = ${env:SUPERVISOR_ACCOUNT_NAME}
AccountAccessKey = ${env:SUPERVISOR_ACCOUNT_ACCESS_KEY}
EnableSSL = ${env:SUPERVISOR_ENABLE_SSL:-true}
```

### 3. Show The Remote Target Model

Generic `remote.yaml` pattern:

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

What each field means:

- `protocol.auth.username` is the SSH login user. It only needs SSH access and write permission to the remote install directory.
- `protocol.auth.privileged: true` means Smart Agent can escalate on the remote host to install a system-wide service.
- `hosts[].user` and `hosts[].group` are the runtime identity for the Smart Agent service itself.
- Those are separate choices. The SSH login user does not have to be the same as the Smart Agent runtime user.

### 3A. Smart Agent Service User/Group Requirements

Use this as the slide-ready summary from the official Smart Agent permissions matrix.

| Agent Type | Recommended `APPD_USER` | Recommended `APPD_GROUP` |
| --- | --- | --- |
| `Java` | `anyUser` | `anyUser` |
| `Node.js` | `anyUser` | `anyUser` |
| `Database` | `anyUser` | `anyUser` |
| `Machine` | `root` | `root` |
| `Apache` | `root` | `root` |
| `Python` | `root` | `root` |
| `PHP` | `root` | `root` |

Presenter line:

- “Smart Agent does not require `root:root` for every agent type. Java, Node.js, and Database can run as any user. Machine, Apache, Python, and PHP are the ones that drive you toward `root:root` if you want one broad profile.”

### 3B. Recommended Demo Pattern

For this demo, use a normal SSH login user and keep Smart Agent itself running as `root:root` on managed hosts.

Recommended explanation:

- SSH to the control host as `ubuntu` or `ec2-user`.
- From the control host, SSH to managed hosts using that normal account.
- Keep `privileged: true` so Smart Agent can install and manage a system-wide service.
- Keep `user: root` and `group: root` in `remote.yaml` for the managed-host Smart Agent runtime.
- Do not use direct root SSH as the primary demo pattern.

PPT-friendly rationale:

- one repeatable profile for the widest set of agent types
- simpler live demo flow
- avoids having to explain per-runtime ownership switches mid-demo

### 3C. Why This Demo Uses `root:root`

Use this talk track directly:

- “For this lab, I am using a normal SSH login account plus privilege escalation, but I am keeping the Smart Agent service itself at `root:root` on the managed hosts.”
- “That is not because Java or Node individually require root. They do not.”
- “It is because I want one repeatable demo profile that can also cover Machine Agent style workflows and other agent types whose default requirement is `root:root`.”
- “This is a demo simplification for breadth, not a least-privilege production recommendation.”

Tradeoffs to call out:

- simpler for a broad demo
- more privilege than Java- or Node-only environments strictly need
- can create root-owned files and service-state side effects on app hosts
- production environments may prefer separate profiles for Java or Node app hosts

Validated lab note:

- The current control node already has `~/appdsm/remote.yaml`
- It targets the private-IP host list from the copied lab profile
- It uses SSH key auth from the control node itself
- In the current lab, the managed-host Smart Agent service is running as `root:root`

### 4. Start Local Smart Agent On The Control Node If Needed

```bash
cd ~/appdsm
sudo ./smartagentctl start --service
sudo ./smartagentctl status
```

Validated live result:

- `Started AppDynamics SmartAgent with ID: ...`
- `status` returned `Running`

### 5. Remote Lifecycle Warning

Do not present this as a safe read-only command:

```bash
sudo ./smartagentctl status --remote
```

Validated live behavior:

- it connected to the remote hosts
- it ran remote status
- it then stopped and synchronized remote Smart Agent services

Use these instead during the demo:

- Agent Management UI
- direct `systemctl status smartagent` on one target host
- a deliberately rehearsed remote `start`, `upgrade`, or `rollback`

Validated latest-bundle rollout path for this brownfield lab:

```bash
cd ~/appdsm-26.3.0.938
sudo ./smartagentctl start --service --remote
```

### 5A. Opening Move: Agent Management Inventory And Windows Upgrade Path

In AppDynamics SaaS:

1. Open `Agent Management > Smart Agents`.
2. Filter to `Smartagent-windows-1` and confirm the host is visible.
3. Confirm the current Windows Smart Agent version is `26.2.0-779`.
4. Click `Upgrade`.
5. Select `26.3.0-938` as the target version and use the rehearsed upgrade option.
6. Watch the deployment status and the Windows host version update in the UI.

Presenter line:

- “This is the control-plane proof for Windows. I am changing lifecycle from AppDynamics UI, not remoting into the server.”
- “I kept this host one version back, so the upgrade is visible and honest.”

Rehearsal gate:

- Only use this live if `Smartagent-windows-1` is already enrolled in `Agent Management > Smart Agents`, still on `26.2.0-779`, and the upgrade target is visible in the UI.
- Keep a host-side PowerShell or Services check ready as a backstage fallback, but let the UI carry the main story.
- Prefer System Properties or EC2Launch console output over `$env:COMPUTERNAME` if you need the full Windows hostname; Windows can expose a shortened 15-character form there.
- Do not use the Linux bundle or the Linux remote rollout path against the Windows host.

Windows post-upgrade verification (per the latest 26.4 Smart Agent upgrade page):

- Windows does not have `systemctl` and does not require a service restart after a successful UI upgrade.
- Verify success via the Agent Management deployment status and the host-side `\upgrade-log.log` (look at the latest entries; the file is rewritten per upgrade attempt).

For the Linux equivalent of this same UI-driven upgrade flow, see Section 5B.

### 5B. Linux Post-Upgrade Restart Sequence (Linux Managed Hosts Only)

This section is Linux-only and not part of the live Windows opening move. Use it as a reference if you (or a customer) drive a Linux Smart Agent upgrade from `Agent Management > Smart Agents` on a managed host such as `smartagent-1`–`smartagent-4`.

Per the 26.4 Smart Agent upgrade page, after a successful UI-driven upgrade on a Linux managed host, run the host-side restart sequence so the service picks up the new binary and `daemon-reload` re-reads any unit-file changes:

```bash
sudo systemctl restart smartagent
sudo systemctl daemon-reload
sudo systemctl restart smartagent
```

Operational notes:

- Run this trio on the managed Linux host, not on the control host (the control host has its own `smartagentctl start --service` flow already covered in Section 4).
- Auto-attach and Deployment Group policy pickup happen on the managed-host restart, so do this before re-running any Java or Node demo flow that depends on the new binary.
- Windows hosts do not have `systemctl` and do not require this step. See the Windows post-upgrade verification note in Section 5A.

### 6. Brownfield Java App On `smartagent-1`

```bash
ssh <ssh-options> <ssh-user>@<control-node-public-ip>
ssh <managed-ssh-options> <managed-ssh-user>@<java-demo-private-ip>
cd ~/spring-petclinic
sed -n '1,20p' run-app.sh
nohup ./run-app.sh >/tmp/petclinic.log 2>&1 < /dev/null &
sleep 8
ss -ltnp | grep 8080
curl -sfI http://127.0.0.1:8080
tail -n 20 /tmp/petclinic.log
```

Validated live result:

- Java bound to `*:8080`
- `curl -I` returned `HTTP/1.1 200`

### 7. Java Combined-Mode Naming

Explain these modes:

- `AGENT_DEPLOYMENT_MODE=appdynamics`
- `AGENT_DEPLOYMENT_MODE=dual`
- `AGENT_DEPLOYMENT_MODE=otel`

Presenter line:

- “The application still launches as a normal brownfield JVM. I am not editing the app startup to add `-javaagent`. Smart Agent auto-attach plus the Deployment Group controls the Java agent behavior.”

Auto-correlation proof point (per latest 26.4 Java dual-signal docs):

- In dual signal mode, the Java Agent automatically stamps these attributes on root spans (and `appd.tier.name` mid-trace whenever the tier changes):
  - `appd.app.name`
  - `appd.bt.name`
  - `appd.tier.name`
  - `appd.request.guid`
- AppDynamics snapshots gain the corresponding `TraceId` under the Data Collectors tab, so a Splunk APM trace and an AppDynamics snapshot are one click apart in either direction.

Presenter line for the round-trip:

- “Dual-signal mode is not just two pipes side by side. The Java Agent stamps `appd.app.name`, `appd.bt.name`, `appd.tier.name`, and `appd.request.guid` on the root span, and the matching `TraceId` shows up on the AppD snapshot. That is the round-trip: one click from a Splunk APM trace to the AppDynamics snapshot, and back.”

### 7A. Deployment Group Auto-Attach For Java

For Java auto-attach through a Deployment Group, the minimal Java system property is:

```text
-Dagent.deployment.mode=dual
```

For a same-host local collector on default settings, that is the minimal dual-mode switch. The latest Splunk AppDynamics Java OTel guidance says that in most cases you should run an OpenTelemetry collector on the same system as the Java Agent, and once that local collector is in place, `AGENT_DEPLOYMENT_MODE=dual` is enough. For Java Agent 25.10 or later, the Combined Agent can auto-populate the required resource attributes from the AppDynamics configuration. Java Agent `26.2.0` upgraded the bundled `splunk-otel-javaagent` from `2.25.0` to `2.26.1`, which is explicitly called out in the 26.2 release notes as a security hardening for Dual Signal mode.

For Agent Management `java_system_properties`, enter the raw `key=value` form without the `-D` prefix:

```text
agent.deployment.mode=dual
```

Operational caveat:

- Apply the Deployment Group before the JVM starts, or restart the JVM after the policy change.
- The latest docs say dynamic attachment is not supported when OpenTelemetry is enabled, so do not promise a no-restart toggle into dual mode for an already-running Java process.
- In the current lab, Smart Agent auto-attach is surfaced through `/etc/profile.d/set-appdynamics-env.sh`, so rehearse the demo from a normal login-shell path.
- Keep `~/spring-petclinic/run-app.sh` plain for the brownfield story. Hand-editing `JAVA_TOOL_OPTIONS` in the app start script can mask a broken Deployment Group configuration.

Deployment Group custom-configuration example for the Java Agent:

```yaml
install_agent_from: appd-portal
user: ubuntu
group: ubuntu
java_system_properties: "agent.deployment.mode=dual"
```

If you are editing only the Agent Management UI field, paste `agent.deployment.mode=dual` without extra outer quotes in the field.

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

If the collector endpoint is not the default local listener, make it explicit:

```yaml
install_agent_from: appd-portal
user: ubuntu
group: ubuntu
java_system_properties: "agent.deployment.mode=dual otel.exporter.otlp.endpoint=http://127.0.0.1:4318 otel.exporter.otlp.protocol=http/protobuf otel.service.name=petclinic otel.resource.attributes=service.namespace=smartagent-demo,deployment.environment.name=fso-tme,host.name=smartagent-1 otel.metrics.exporter=none otel.logs.exporter=none"
```

Important field-formatting note:

- Do not include leading `-D` in `java_system_properties`; Smart Agent prepends that when it assembles the JVM args.
- Do not wrap the whole UI field in doubled outer quotes.
- In the UI, type raw values without quotes and let the renderer add a single quote layer if it wants to.

Important distinction:

- The local collector is a separate OpenTelemetry Collector process.
- The local collector is not the Machine Agent.
- In dual mode, the Combined Agent still sends AppDynamics APM data to the Controller directly.
- The local collector is only for forwarding the OpenTelemetry side to Splunk Observability Cloud.
- In this lab, `smartagent-1` already has a healthy minimal collector on `127.0.0.1:4317`, `127.0.0.1:4318`, and `127.0.0.1:13133`.

### 7B. Local Collector On `smartagent-1`

In the current lab, `smartagent-1` already has a minimal same-host collector installed and healthy. If you want install motion during rehearsal or live delivery, rerun the repo helper and narrate that it safely reuses the package and refreshes the minimal config.

Best practice from the latest docs:

- use the Cisco AppDynamics Distribution for OpenTelemetry Collector
- prefer the repo helper with `--use-splunk-installer` when the host has network egress
- use the same helper live if you want install motion; it is now idempotent
- keep the archive workflow only as a backstage fallback for restricted environments
- use your Splunk Observability Cloud realm and access token for the collector export path
- verify `splunk-otel-collector` is active, health on `127.0.0.1:13133`, and listeners on `127.0.0.1:4317` and `127.0.0.1:4318`

Repeatable repo helper:

```bash
bash skills/smartagent-lab/scripts/install_local_collector.sh \
  --profile <copied-profile> \
  --use-splunk-installer \
  --execute
```

Restricted-egress contingency only:

```bash
bash skills/smartagent-lab/scripts/install_local_collector.sh \
  --profile <copied-profile> \
  --archive <local-collector-archive> \
  --execute
```

Presenter line:

- “This host already has the local collector path prepared, and if I want to show the install motion I rerun the same helper. AppDynamics still goes straight to the Controller, and this local collector is only here for the O11y side.”

Minimal environment block for a same-host local collector:

```bash
export AGENT_DEPLOYMENT_MODE=dual
```

Optional explicit override block if you want to pin naming or a non-default collector endpoint:

```bash
export AGENT_DEPLOYMENT_MODE=dual
export OTEL_SERVICE_NAME=petclinic
export OTEL_RESOURCE_ATTRIBUTES=service.namespace=smartagent-demo,deployment.environment.name=fso-tme,host.name=smartagent-1
export OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
export OTEL_EXPORTER_OTLP_ENDPOINT=http://127.0.0.1:4318
export OTEL_LOGS_EXPORTER=none
```

### 8. Optional Node.js Path On `smartagent-2`

Validated live facts:

- `smartagent-2` has Node.js installed
- `node -v` returned `v22.22.0`
- `~/weather-app/src` is present on the host
- `node server.js` is listening on `3000`
- the running process carries Smart Agent `LD_PRELOAD`
- the live Node agent log shows controller connectivity, node registration, and BT `/` registration

Only use the Node runtime in the live demo if you keep this app state intact or revalidate it before the session.

Managed-host access should still go through the control host and private IPs.

### 9. Combined Machine Agent Path On `smartagent-3`

Smart Agent `26.3.0` introduced the Combined Agent for Infrastructure Visibility (Combined Machine Agent, CMA). That makes `smartagent-3` the infrastructure analog of the Java dual-signal story on `smartagent-1`: one Machine Agent package, three selectable modes.

Current live finding:

- `appdynamics-machine-agent.service` is active
- `/opt/appdynamics/machine-agent/bin/machine-agent` exists
- the path now passes `bash skills/smartagent-lab/scripts/validate_lab.sh --profile <copied-profile> --require-machine-agent`

Combined Machine Agent modes (per latest docs):

| Mode | Behavior | Toggle (env / `-D` / `controller-info.xml`) |
| --- | --- | --- |
| Machine Agent (default) | Java Machine Agent reports to AppDynamics Controller only. Existing visibility unchanged. | default, or `SPLUNK_OTEL_ENABLED=false` / `-Dsplunk.otel.enabled=false` / `false` |
| Dual signal | Machine Agent and the Splunk OTel Collector run as independent processes. AppD/Tier/Node auto-map to OTel resource attributes. Collector failure does not impact AppD reporting. | `SPLUNK_OTEL_ENABLED=true` / `-Dsplunk.otel.enabled=true` / `true` |
| OTel only | JVM-based Machine Agent process is skipped. Only the Splunk OTel Collector runs. | `SPLUNK_OTEL_ONLY=true` / `-Dsplunk.otel.only=true` (env or `-D`) |

Required environment for either dual signal or OTel only mode:

- `SPLUNK_ACCESS_TOKEN` (required)
- `SPLUNK_REALM` (required, for example `us0`, `us1`, `eu0`)
- `DEPLOYMENT_ENVIRONMENT` (optional grouping label)
- `SPLUNK_API_URL` defaults to `https://api.${SPLUNK_REALM}.signalfx.com`
- `SPLUNK_INGEST_URL` defaults to `https://ingest.${SPLUNK_REALM}.signalfx.com`

Steady state to preserve before demo day:

- keep `appdynamics-machine-agent.service` active
- validate the infrastructure view in AppDynamics and, if you plan to show it, the paired Splunk Observability Cloud infrastructure view from CMA dual-signal output
- run `bash skills/smartagent-lab/scripts/validate_lab.sh --profile <copied-profile> --require-machine-agent`

Useful host-side proof:

```bash
systemctl status appdynamics-machine-agent --no-pager -l
test -x /opt/appdynamics/machine-agent/bin/machine-agent && echo "machine_agent_binary=yes"
journalctl -u appdynamics-machine-agent --since '-5 min' --no-pager | tail -n 20
ls -l /opt/appdynamics/machine-agent/logs/otel/otel_collector.log 2>/dev/null || true
```

Presenter line:

- “Smart Agent 26.3 turned the Machine Agent into a Combined Machine Agent. The same dual-signal story I just told for the JVM on `smartagent-1` now applies one-for-one to the host on `smartagent-3`. Default mode is unchanged for safety. Setting `SPLUNK_OTEL_ENABLED=true` enables dual signal to AppD plus Splunk Observability Cloud. `SPLUNK_OTEL_ONLY=true` is the eventual end state when AppD reporting is no longer needed.”

Demo-day caveat:

- This lab keeps `smartagent-3` in default Machine Agent mode for safety. Only flip CMA into dual-signal mode live if you have rehearsed the env-var change, restart, and Splunk O11y dashboard view in advance, and revalidated `--require-machine-agent` afterwards.

## UI Checkpoints

- Agent Management inventory showing the managed Linux hosts
- Agent Management inventory showing `Smartagent-windows-1`
- `Smartagent-windows-1` showing current version `26.2.0-779`
- Upgrade status or version change to `26.3.0-938` for the Windows host
- Control node Smart Agent status if you start it locally
- Controller visibility for Petclinic
- O11y visibility for Java dual-signal mode if configured
- Infrastructure visibility for `smartagent-3` after Machine Agent repair

## Safe Demo Mode

1. Move to `Agent Management > Smart Agents` and confirm `Smartagent-windows-1` is still on `26.2.0-779`.
2. Run the rehearsed upgrade to `26.3.0-938` and leave the UI showing rollout status.
3. Show `smartagentctl-base` and explain `SUPERVISOR_*`.
4. Show `remote.yaml` and the existing managed-host list.
5. Start `~/spring-petclinic` on `smartagent-1` and validate `HTTP 200`.
6. If you want collector install motion, rerun the idempotent helper on `smartagent-1`, then explain `AGENT_DEPLOYMENT_MODE` and dual-signal behavior.
7. Show `smartagent-3` only after `--require-machine-agent` passes.
8. Skip Node unless pre-staged.

## Appendix Talking Points

- `smartagentctl` is the active control utility; the older Smart Agent CLI is deprecated and reaches end of support on February 2, 2026.
- Smart Agent `26.2.0` added stronger remote-host support in `remote.yaml`: SSH password authentication plus SOCKS5 and HTTP proxy options for remote operations. Useful when reaching managed hosts only via bastion or jump-host networking.
- Smart Agent `26.3.0` is also a security refresh: Logback Core `1.2.9 → 1.5.25`, Logback Classic `1.2.9 → 1.2.13`, exe4j `5.0.1 → 10.0.1`, Jetty `9.4.44 → 9.4.57` (Server) and `9.4.44 → 12.0.12` (HTTP). That is part of the "why we keep the cadence" story for the Windows upgrade move.
- Smart Agent `26.3.0` also introduced Combined Agent for Infrastructure Visibility (CMA): Machine Agent default, dual signal (`SPLUNK_OTEL_ENABLED=true`), and OTel only (`SPLUNK_OTEL_ONLY=true`). Section 9 covers the live `smartagent-3` framing.
- Java Agent `26.2.0` upgraded the bundled `splunk-otel-javaagent` from `2.25.0` to `2.26.1`, explicitly called out as a Dual Signal mode security hardening.
- Java Agent `26.2.0` DockerHub images transitioned from Alpine to a Scratch base. Worth a one-line answer if Kubernetes or container hardening comes up in Q&A: smaller attack surface and no in-image shell.
- .NET Combined Agent (Splunk-only mode and Dual signal mode) is GA as of `26.2.0`. It is appendix material here only because it is not pre-staged in this lab, not because it is unsupported.
- Java and Node are the cleanest live runtime story here.
- Use Windows as a UI-driven lifecycle proof point, not a live RDP sequence.

## Source Material

- https://help.splunk.com/en/appdynamics-on-premises/agent-management/26.4.0/smart-agent/before-you-begin
- https://help.splunk.com/en/appdynamics-saas/agent-management/26.4.0/smart-agent/get-started/install-smart-agent
- https://help.splunk.com/en/appdynamics-on-premises/agent-management/26.4.0/smart-agent/manage-the-agents-using-smartagentctl/install-supported-agents-using-smartagentctl/requirements-to-install-supported-agent-on-a-remote-host
- https://help.splunk.com/en/appdynamics-saas/agent-management/26.4.0/smart-agent/get-started/configure-smart-agent
- https://help.splunk.com/en/appdynamics-saas/agent-management/26.4.0/smart-agent/upgrade-smart-agent
- https://help.splunk.com/en/appdynamics-saas/agent-management/26.4.0/smart-agent/auto-attach-java-and-nodejs-agents
- https://help.splunk.com/en/appdynamics-on-premises/agent-management/26.4.0/smart-agent/configuration-options-for-supported-agents/configuration-options-for-java-agent
- https://help.splunk.com/en/appdynamics-on-premises/agent-management/26.4.0/smart-agent/manage-the-agents-using-smartagentctl/install-supported-agents-using-smartagentctl/ssh-configuration-for-remote-host
- https://help.splunk.com/en/appdynamics-saas/application-performance-monitoring/26.4.0/splunk-appdynamics-for-opentelemetry/instrument-applications-with-splunk-appdynamics-for-opentelemetry/monitor-applications-with-combined-agent
- https://help.splunk.com/en/appdynamics-saas/application-performance-monitoring/26.4.0/splunk-appdynamics-for-opentelemetry/instrument-applications-with-splunk-appdynamics-for-opentelemetry/enable-opentelemetry-in-the-java-agent/enable-dual-signal-mode
- https://help.splunk.com/en/appdynamics-saas/application-performance-monitoring/26.4.0/splunk-appdynamics-for-opentelemetry/instrument-applications-with-splunk-appdynamics-for-opentelemetry/enable-opentelemetry-in-the-java-agent/configure-opentelemetry
- https://help.splunk.com/en/appdynamics-on-premises/application-performance-monitoring/26.4.0/splunk-appdynamics-for-opentelemetry/configure-the-opentelemetry-collector/cisco-appdynamics-distribution-for-opentelemetry-collector
- https://help.splunk.com/en/appdynamics-on-premises/application-performance-monitoring/26.4.0/splunk-appdynamics-for-opentelemetry/configure-the-opentelemetry-collector/configure-exporters
- https://help.splunk.com/en/appdynamics-on-premises/application-performance-monitoring/26.4.0/splunk-appdynamics-for-opentelemetry/configure-the-opentelemetry-collector/collector-configuration-sample
- https://help.splunk.com/en/appdynamics-on-premises/application-performance-monitoring/26.4.0/splunk-appdynamics-for-opentelemetry/configure-the-opentelemetry-collector/start-the-collector
- https://help.splunk.com/en/appdynamics-on-premises/application-performance-monitoring/26.4.0/splunk-appdynamics-for-opentelemetry/instrument-applications-with-splunk-appdynamics-for-opentelemetry/enable-opentelemetry-in-the-node.js-agent/dual-signal-mode-for-node.js-combined-agent
- https://help.splunk.com/en/appdynamics-saas/infrastructure-visibility/26.3.0/machine-agent/combined-agent-for-infrastructure-visibility
- https://help.splunk.com/en/appdynamics-saas/release-notes-and-references/agents-release-notes/26.2.0/agent-enhancements
- https://help.splunk.com/en/appdynamics-saas/release-notes-and-references/agents-release-notes/26.3.0/agent-enhancements
- https://help.splunk.com/en/appdynamics-saas/release-notes-and-references/agents-release-notes/26.4.0/agent-enhancements
