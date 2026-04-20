# Smart Agent 45-Minute Demo Script

Last updated: April 20, 2026

## Repeatable Entry Point

Preferred operator workflow: use the repo-local `$smartagent-lab` skill in [skills/smartagent-lab](/Users/alecchamberlain/Documents/GitHub/smartagent_clus26/skills/smartagent-lab) with a lab profile before following the live script. The skill is built around a public control host plus private-VPC managed targets.

Use the validator before rehearsal:

```bash
bash skills/smartagent-lab/scripts/validate_lab.sh --profile <copied-profile>
```

It exits non-zero on critical demo drift and leaves appendix-only checks as warnings.

## Goal

Show Splunk AppDynamics Smart Agent as the lifecycle control plane for a mixed estate, then show how that same estate can move into OpenTelemetry and Splunk Observability Cloud without throwing away AppDynamics value.

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
- `smartagent-2` has Node.js installed and returned `v24.13.0`, but no Node demo app was staged live.
- `appdynamics-machine-agent.service` is failed on the Linux app hosts because `/opt/appdynamics/machine-agent/bin/machine-agent` is missing.

## Important Live Caveats

- For this exact lab, the honest story is brownfield lifecycle control, not first-ever Smart Agent installation. The Linux managed hosts are already enrolled.
- If you want a “fresh install” moment, prepare a new Linux host or deliberately reset a target during rehearsal.
- For Java dual mode with a local collector, the collector is a separate OpenTelemetry Collector process on the same host as the Java runtime. It is not the Machine Agent.
- The current lab already has a minimal same-host collector on `smartagent-1`. If you want the install motion on stage, rerun the repo helper and narrate that it is idempotent.
- `smartagentctl status --remote` is not safe to present as a harmless read-only check on this `26.2.0-779` control node. During validation it stopped and synchronized remote Smart Agent services.
- For the current latest-bundle rollout, `/opt/appdynamics/appdsmartagent` and `/opt/appdynamics/appdsmartagent/staging` on the managed Linux hosts must stay writable by the SSH login user `ubuntu`.
- Do not rehearse `migrate --remote` on already-enrolled hosts with `26.3.0.938`; it can zero the managed-host `config.ini`.
- The durable control-host `LD_PRELOAD` fix is already applied. Fresh SSH logins should now be clean.

## Audience Message

- Operations teams get centralized rollout, upgrade, and attach control.
- Application teams keep AppDynamics concepts while adding OpenTelemetry signals.
- Platform teams standardize on environment-variable naming instead of host-specific snowflake config.

## Validated Lab Inventory

Private VPC IPs are the primary live addresses for the demo. Public or bastion entry details belong in the copied lab profile or in [current-lab.md](/Users/alecchamberlain/Documents/GitHub/smartagent_clus26/skills/smartagent-lab/references/current-lab.md), not in the generic talk track.

| Host | Instance ID | OS | Address Source | Role In Demo |
| --- | --- | --- | --- | --- |
| `smartagentctl-base` | `i-046e9fb473d39d9bc` | Ubuntu 22.04 | control-host address from the copied lab profile | Launcher host, Smart Agent bundle in `~/appdsm` |
| `smartagent-1` | `i-0af7f834c3c25e189` | Ubuntu 22.04 | private VPC IP from the copied lab profile | Primary Java brownfield host with `~/spring-petclinic` |
| `smartagent-2` | `i-0e1108e2654c3da61` | Ubuntu 22.04 | private VPC IP from the copied lab profile | Optional Node.js host |
| `smartagent-3` | `i-0b95f120775a511d3` | Ubuntu 24.04 | private VPC IP from the copied lab profile | Infra appendix host, stale Machine Agent service currently broken |
| `smartagent-4` | `i-0c077b933a1e0353b` | Ubuntu 24.04 | private VPC IP from the copied lab profile | Reset/reinstall target if you want a first-install rehearsal |
| `Smartagent-windows-1` | `i-0d9d7fdee7998d8ab` | Windows | appendix address from the copied lab profile | Appendix only |

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
| `6:00-10:00` | SSH to `smartagentctl-base` and open `config.ini`. | “Notice the naming convention. `SUPERVISOR_*` gives you portable controller configuration. Also notice that the preload issue was fixed cleanly at the host level, not hidden with ad hoc shell tricks.” | Shows platform configuration and good demo hygiene. |
| `10:00-15:00` | Show `remote.yaml`, the managed target list, and the user/group model. If local Smart Agent is stopped, start it. | “In this lab the Linux nodes are already enrolled, so the honest proof is lifecycle control and synchronization, not a fake fresh install story. Also notice the identity split: SSH user, privilege escalation, and Smart Agent runtime user are different decisions.” | Keeps the narrative aligned with the actual lab state and explains the permission model clearly. |
| `15:00-19:00` | Move to Agent Management UI. | “This is where operations wins: inventory, rollout posture, and lifecycle are visible in product, not buried in SSH history.” | Confirms the control model in the UI. |
| `19:00-27:00` | SSH to `smartagent-1`, show `~/spring-petclinic`, start it, and validate `HTTP 200`. | “This is the brownfield attach story. The app is already on the box. I’m not rebuilding it. I’m making an existing workload observable.” | Live-validated Java app startup on port `8080`. |
| `27:00-33:00` | On `smartagent-1`, verify the local collector or rerun the idempotent installer helper if you want to show the install motion, then show the Java Deployment Group settings for auto-attach and explain `AGENT_DEPLOYMENT_MODE`. | “The migration pivot is not a code rewrite. The app still starts normally. This host already has the collector path prepared, and the same helper can reapply it safely. The Deployment Group policy then decides the behavior.” | Shows that no manual `-javaagent` is needed, that the collector is separate from Machine Agent, and that dual mode is controlled by Java system properties. |
| `33:00-37:00` | Optional: show that `smartagent-2` has Node.js and only run Node if the app is already staged. | “Node follows the same model, but only put it on stage if the app is prepared before the session.” | Reinforces cross-runtime consistency without creating dead air. |
| `37:00-40:00` | Show `smartagent-3` only as appendix unless repaired. | “This host is useful because it shows a real brownfield truth: stale services exist. Here the Machine Agent unit exists, but the binary does not.” | Turns a lab flaw into a credible operator note. |
| `40:00-45:00` | Close with release improvements, appendix points, and Q&A. | “The message is central lifecycle control, clean naming, brownfield attach, and a controlled path to OpenTelemetry.” | Reinforces the operating model. |

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

### 7A. Deployment Group Auto-Attach For Java

For Java auto-attach through a Deployment Group, the minimal Java system property is:

```text
-Dagent.deployment.mode=dual
```

For a same-host local collector on default settings, that is the minimal dual-mode switch. The latest Splunk AppDynamics Java OTel guidance says that in most cases you should run an OpenTelemetry collector on the same system as the Java Agent, and once that local collector is in place, `AGENT_DEPLOYMENT_MODE=dual` is enough. For Java Agent 25.10 or later, the Combined Agent can auto-populate the required resource attributes from the AppDynamics configuration.

Operational caveat:

- Apply the Deployment Group before the JVM starts, or restart the JVM after the policy change.
- The latest docs say dynamic attachment is not supported when OpenTelemetry is enabled, so do not promise a no-restart toggle into dual mode for an already-running Java process.

Deployment Group custom-configuration example for the Java Agent:

```yaml
install_agent_from: appd-portal
user: ubuntu
group: ubuntu
java_system_properties: "-Dagent.deployment.mode=dual"
```

If the collector endpoint is not the default local listener, make it explicit:

```yaml
install_agent_from: appd-portal
user: ubuntu
group: ubuntu
java_system_properties: "-Dagent.deployment.mode=dual -Dotel.exporter.otlp.endpoint=http://127.0.0.1:4318 -Dotel.exporter.otlp.protocol=http/protobuf"
```

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
- `node -v` returned `v24.13.0`
- no Node demo app was staged during live validation

Only use the Node runtime in the live demo if the app is already copied and tested before the session.

Managed-host access should still go through the control host and private IPs.

### 9. Optional Machine Agent Appendix On `smartagent-3`

Validated live finding:

- `appdynamics-machine-agent.service` is failed
- the service expects `/opt/appdynamics/machine-agent/bin/machine-agent`
- that binary is missing

Treat this as appendix unless you repair it before demo day.

## UI Checkpoints

- Agent Management inventory showing the managed Linux hosts
- Control node Smart Agent status if you start it locally
- Controller visibility for Petclinic
- O11y visibility for Java dual-signal mode if configured
- Appendix only: infrastructure visibility after Machine Agent repair

## Safe Demo Mode

1. Show `smartagentctl-base` and explain `SUPERVISOR_*`.
2. Show `remote.yaml` and the existing managed-host list.
3. Move to Agent Management UI.
4. Start `~/spring-petclinic` on `smartagent-1` and validate `HTTP 200`.
5. If you want collector install motion, rerun the idempotent helper on `smartagent-1`, then explain `AGENT_DEPLOYMENT_MODE` and dual-signal behavior.
6. Skip Node unless pre-staged.
7. Keep Machine Agent in appendix unless repaired.

## Appendix Talking Points

- `smartagentctl` is the active control utility; the older Smart Agent CLI is deprecated.
- Smart Agent 26.2 added stronger remote-host support, including SSH password auth and HTTP or SOCKS5 proxy settings.
- Java and Node are the cleanest live runtime story here.
- .NET combined mode remains appendix material unless you prepare it deliberately.

## Source Material

- https://help.splunk.com/en/appdynamics-on-premises/agent-management/26.4.0/smart-agent/before-you-begin
- https://help.splunk.com/en/appdynamics-on-premises/agent-management/26.1.0/smart-agent/get-started/install-smart-agent
- https://help.splunk.com/en/appdynamics-on-premises/agent-management/26.1.0/smart-agent/manage-the-agents-using-smartagentctl/install-supported-agents-using-smartagentctl/requirements-to-install-supported-agent-on-a-remote-host
- https://help.splunk.com/en/appdynamics-saas/agent-management/26.1.0/smart-agent/get-started/configure-smart-agent
- https://help.splunk.com/en/appdynamics-saas/agent-management/26.4.0/smart-agent/auto-attach-java-and-nodejs-agents
- https://help.splunk.com/en/appdynamics-on-premises/agent-management/26.4.0/smart-agent/auto-deploy-agents-with-deployment-groups/create-a-deployment-group
- https://help.splunk.com/en/appdynamics-on-premises/agent-management/25.10.0/smart-agent/configuration-options-for-supported-agents/configuration-options-for-java-agent
- https://help.splunk.com/en/appdynamics-on-premises/agent-management/26.4.0/smart-agent/manage-the-agents-using-smartagentctl/install-supported-agents-using-smartagentctl/ssh-configuration-for-remote-host
- https://help.splunk.com/en/appdynamics-saas/application-performance-monitoring/26.2.0/splunk-appdynamics-for-opentelemetry/instrument-applications-with-splunk-appdynamics-for-opentelemetry/monitor-applications-with-combined-agent
- https://help.splunk.com/en/appdynamics-saas/application-performance-monitoring/26.4.0/splunk-appdynamics-for-opentelemetry/instrument-applications-with-splunk-appdynamics-for-opentelemetry/enable-opentelemetry-in-the-java-agent/enable-dual-signal-mode
- https://help.splunk.com/en/appdynamics-saas/application-performance-monitoring/26.4.0/splunk-appdynamics-for-opentelemetry/instrument-applications-with-splunk-appdynamics-for-opentelemetry/enable-opentelemetry-in-the-java-agent/configure-opentelemetry
- https://help.splunk.com/en/appdynamics-on-premises/application-performance-monitoring/26.3.0/splunk-appdynamics-for-opentelemetry/configure-the-opentelemetry-collector/cisco-appdynamics-distribution-for-opentelemetry-collector
- https://help.splunk.com/en/appdynamics-on-premises/application-performance-monitoring/26.2.0/splunk-appdynamics-for-opentelemetry/configure-the-opentelemetry-collector/configure-exporters
- https://help.splunk.com/en/appdynamics-on-premises/application-performance-monitoring/26.2.0/splunk-appdynamics-for-opentelemetry/configure-the-opentelemetry-collector/collector-configuration-sample
- https://help.splunk.com/en/appdynamics-on-premises/application-performance-monitoring/26.2.0/splunk-appdynamics-for-opentelemetry/configure-the-opentelemetry-collector/start-the-collector
- https://help.splunk.com/en/appdynamics-on-premises/application-performance-monitoring/26.3.0/splunk-appdynamics-for-opentelemetry/instrument-applications-with-splunk-appdynamics-for-opentelemetry/enable-opentelemetry-in-the-node.js-agent/dual-signal-mode-for-node.js-combined-agent
- https://help.splunk.com/en/appdynamics-on-premises/infrastructure-visibility/26.3.0/machine-agent/combined-agent-for-infrastructure-visibility
- https://help.splunk.com/en/appdynamics-saas/release-notes-and-references/agents-release-notes/26.2.0/agent-enhancements
