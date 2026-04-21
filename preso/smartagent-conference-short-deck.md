# Smart Agent Conference Deck

Derived from `smartagent-architecture.md`, `smartagent-demo-script.md`, and `smartagent-lab-guide.md`.

## Slide 1: Splunk AppDynamics Smart Agent Design and Best Practices
- Brownfield attach, remote rollout, and a controlled path to OpenTelemetry
- Alec Chamberlain
- Senior Staff Technical Marketing Engineer
- Session focus
- Remote rollout, brownfield attach, and dual-signal migration
- Session ID: CISCOU-2057

## Slide 2: Why This Story Matters
- Why This Story Matters
- Brownfield estates need lifecycle control before they need another one-off agent install.

## Slide 3: The Problem Is Operational
- The problem is not agent capability.
- It is lifecycle drift and operational sprawl.
- Lifecycle
- Drift
- Sprawl

## Slide 4: What This Demo Proves
- Outcomes
- Centralize
- One control host can manage rollout and posture.
- Attach
- Brownfield Java stays in place and attaches in place.
- Migrate
- Add OTel signals without throwing away AppDynamics.

## Slide 5: Control Plane vs. Data Plane
- Control plane
- Deploy, start, and auto-attach from one hub.
- Turn fresh hosts into managed hosts remotely.
- Telemetry plane
- Keep AppDynamics BTs and Controller workflows.
- Send OTLP traces and infra signals to Splunk O11y.

## Slide 6: Five Hosts, One Story
- Lab topology
- Five Hosts, One Operating Model
- One control node runs Smart Agent and smartagentctl.
- One Java host proves brownfield attach with Petclinic.
- One optional Node.js host extends the same lifecycle pattern.
- Two more hosts cover infra visibility and controlled re-enrollment.

## Slide 7: Who Wins
- Audience
- Operations, app, and platform teams all get something useful.
- Operations teams get centralized rollout and upgrade posture.
- Application teams keep AppDynamics while adding OTel signals.
- Platform teams standardize config with environment variables.

## Slide 8: Demo Flow
- Demo flow
- From the control host to managed proof

## Slide 9: Remote Deployment Is The Wow Moment
- Start on the control host.
- Show env-driven Smart Agent config.
- Run remote start on smartagent-4.
- Confirm registration in Agent Management.

## Slide 10: Agent Management Validation
- Managed inventory appears in the UI.
- Deployment Group policy turns on auto-attach.
- Versioning and rollout posture become visible.

## Slide 11: Java, Node.js, and Infrastructure
- Application runtimes
- Java Petclinic is the brownfield proof.
- smartagent-1 now has a minimal local collector ready.
- Rerun the idempotent helper if you want to show install motion.
- Infrastructure
- The collector is separate from the Machine Agent.
- AppD still goes directly to the Controller.
- Collector health is live on 13133, 4317, and 4318.
- Machine Agent stays appendix-only in this lab.

## Slide 12: The Operating Model
- Two teams, one workflow
- Operations
- Central lifecycle control
- Remote rollout and inventory
- Application owners
- Brownfield attach
- No rewrite, gradual OTel migration

## Slide 13: Configuration Model
- Three names to remember
- SUPERVISOR_*
- Smart Agent and controller settings
- AGENT_DEPLOYMENT_MODE
- java_system_properties uses raw key=value
- Paste raw values into the UI
- Trust host proof over UI preview
- SPLUNK_* and OTEL_*
- Collector and direct-export settings

## Slide 14: User, Group, and Privilege Options
- Lab default
- We use root:root in the lab.
- It is the fastest demo path.
- It is not the only supported model.
- Production options
- Set Smart Agent with --user and --group.
- Remote SSH user must own or write remote_dir.
- Use a dedicated service account where possible.
- When root/admin is needed
- Service install typically starts with sudo.
- Machine Agent may need elevated rights for privileged metrics.
- Crash Guard or protected hosts can require root/admin access.

## Slide 15: Key Takeaways
- What the audience should leave with
- Centralize
- One control host can manage many targets
- Attach
- Brownfield Java can be instrumented in place
- Migrate
- Dual-signal mode creates a low-risk OTel path
- Broaden
- The story extends to Node.js and infrastructure

## Slide 16: Questions and Discussion
- Questions and discussion
- Rollout, service accounts, brownfield attach, and dual-signal migration.

## Slide 17: Continue the Discussion in Webex
- Find this session in the Cisco Live Mobile App
- Continue the discussion
- Search for CISCOU-2057 in the Cisco Live mobile app
- Join the Webex space when it appears
- Ask follow-up questions after the session
- Splunk AppDynamics Smart Agent Design and Best Practices
- 

## Slide 18: Complete Your Session Evaluations
- Complete your session evaluations
- Earn
- 100 points per survey completed
- and compete on the Cisco Live Challenge leaderboard.
- Level up
- and earn exclusive prizes!
- Complete your surveys
- in the Cisco Live mobile app.
- Complete
- your session survey and the overall event survey
- before surveys close.

## Slide 19: Thank You
- Thank you
