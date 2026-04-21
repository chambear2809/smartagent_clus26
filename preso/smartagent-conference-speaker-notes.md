# Smart Agent Conference Speaker Notes

Speaker notes embedded in `smartagent-conference-short-deck.pptx`.

## Slide 1: Splunk AppDynamics Smart Agent Design and Best Practices
- Frame this as an operating-model story, not a feature checklist.
- The core message is that Smart Agent becomes the lifecycle control layer for a mixed estate.
- From there, teams can preserve AppDynamics workflows while adding OpenTelemetry and Splunk Observability Cloud.
- Tell the audience this deck is based on a live EC2 lab, so the examples are concrete rather than hypothetical.

## Slide 2: Why This Story Matters
- Most customers are not starting from a clean slate; they already have live applications, mixed hosts, and some AppDynamics footprint.
- The real friction is deployment consistency, upgrade posture, configuration drift, and uncertainty about how to adopt OpenTelemetry safely.
- That is why Smart Agent matters. It solves lifecycle control first and telemetry modernization second.
- Set the expectation that every slide after this one ties back to reducing operational friction.

## Slide 3: The Problem Is Operational
- Emphasize that the market already has plenty of agents. Capability is not the bottleneck.
- The hard part is host-by-host installation, one-off configuration, and different runtime behavior across environments.
- Lifecycle drift means versions diverge, auto-attach settings vary, and teams lose confidence in what is actually deployed.
- That is why the slide reduces the problem to three words: lifecycle, drift, and sprawl.

## Slide 4: What This Demo Proves
- Use this slide as the thesis for the whole presentation.
- First, prove centralized lifecycle control from one Smart Agent host.
- Second, prove that brownfield Java does not need to be redesigned or relocated.
- Third, show that AppDynamics value and OpenTelemetry signals can coexist on the same estate.
- Finally, remind the audience that this is a day-two operations improvement, not just an APM demo.

## Slide 5: Control Plane vs. Data Plane
- Separate lifecycle from telemetry because that makes the architecture easier to reason about.
- On the control-plane side, Smart Agent and smartagentctl manage install, start, attach, and posture.
- On the telemetry side, AppDynamics SaaS and Splunk Observability Cloud remain the destinations for the signals.
- This is the key migration point: teams can modernize the data plane without disrupting the lifecycle plane.

## Slide 6: Five Hosts, One Story
- Walk the room through the lab quickly and keep the emphasis on roles rather than IP addresses.
- The presenter only needs to operate directly from the control node, which is what makes the rollout story credible.
- smartagent-1 is the brownfield Java proof point, smartagent-2 provides optional Node.js breadth, smartagent-3 covers infrastructure, and smartagent-4 is the fresh install target.
- The specific EC2 lab is incidental. The pattern is what should generalize to a real estate.

## Slide 7: Who Wins
- Speak directly to the three stakeholder groups that usually evaluate this story.
- Operations teams care about reducing manual SSH work and turning deployment into a managed workflow.
- Application teams care that Business Transactions, snapshots, and Controller workflows stay intact while telemetry options expand.
- Platform teams care that configuration becomes standardized and portable through environment variables.

## Slide 8: Demo Flow
- Preview the run of show so the audience understands the logic of the demo before commands start flying.
- Start with architecture, move into configuration, then show remote deployment and UI validation.
- After that, pivot into brownfield Java, optional Node.js breadth, and infrastructure coverage.
- If time gets compressed, say explicitly that Java plus infrastructure is still enough to prove the operating model.

## Slide 9: Remote Deployment Is The Wow Moment
- Slow down on this slide because this is the clearest live proof of central lifecycle control.
- Show the control host configuration first so the audience sees that the setup is env-driven rather than hand-edited for one machine.
- Then run remote start against smartagent-4 and narrate that a fresh host is becoming managed without a bespoke install session.
- The command itself matters less than the operational pattern it demonstrates.

## Slide 10: Agent Management Validation
- Move from terminal proof to UI proof. That shift is important for credibility with operations leaders.
- Show that the newly managed host appears with recognizable metadata and state in Agent Management.
- Call out that the Java process still starts normally and that the Deployment Group controls auto-attach rather than a hand-edited -javaagent startup line.
- Use this moment to connect the live demo to governance concerns like inventory, upgrade groups, and rollback posture.
- This is where the story becomes operational rather than purely technical.

## Slide 11: Java, Node.js, and Infrastructure
- Reinforce that Java is the critical proof point because the application already exists on the host.
- The latest Java dual-mode guidance says that in most cases you should run an OpenTelemetry collector on the same system as the Java Agent, and once that collector is in place the runtime JVM property is -Dagent.deployment.mode=dual.
- In Agent Management, the java_system_properties field expects raw key=value entries without the -D prefix and without doubled outer quotes.
- The UI can normalize the field and render one set of quotes after save. That is fine. The real mistake is doubled quotes from pasting quoted values into a field that already adds its own quoting.
- A useful demo proof point is the host-side file /opt/appdynamics/appdsmartagent/profile/java/.manage/info.json. When that file shows java_system_properties as a clean key=value string, you know the Deployment Group has reached the host before you restart the JVM.
- Trust info.json over the rendered field text. If auto-attach still looks off, the Smart Agent log shows the actual remote auto_attach payload the host received.
- In the current lab, smartagent-1 already has a minimal same-host collector installed and healthy, so the honest live story is verify it or rerun the idempotent installer helper if you want to show the install motion.
- The canonical operator path is the repo helper with --use-splunk-installer. Archive mode is only the restricted-egress contingency now.
- That helper reuses an existing package, rewrites the host to a minimal collector config, and keeps the story focused on Java dual mode rather than extra distro defaults.
- Also call out the operational caveat: the current docs say dynamic attachment is not supported when OpenTelemetry is enabled, so have the Deployment Group policy in place before the JVM starts or restart the JVM after the change.
- If you are proving Smart Agent auto-attach, keep the application startup script plain. Hand-edited JAVA_TOOL_OPTIONS can make a bad Deployment Group look correct.
- Be explicit that the local collector is a separate OpenTelemetry Collector process and not the Machine Agent, and that AppDynamics APM data still goes directly to the Controller.
- In this lab, the Machine Agent remains appendix-only because the service is broken, while the local collector on smartagent-1 is already healthy on 13133, 4317, and 4318.
- Node.js stays optional, but the operating model remains the same across runtimes.

## Slide 12: The Operating Model
- Use this slide to summarize responsibilities instead of technology components.
- Operations owns lifecycle, remote rollout, and managed posture.
- Application owners keep service context and can change telemetry behavior without redesigning the application.
- The important phrase here is one workflow, because that is what lowers organizational friction.

## Slide 13: Configuration Model
- This is the naming slide, and it matters because naming is what makes the demo portable between labs and environments.
- SUPERVISOR_* covers Smart Agent and controller connectivity.
- The latest dual-mode docs say that in most cases you should run a local collector on the same system, and once that collector is in place the runtime JVM property is -Dagent.deployment.mode=dual.
- In Agent Management, java_system_properties is not pasted as JVM flags. The field expects raw key=value entries, so the concise Deployment Group example is install_agent_from: appd-portal, user: ubuntu, group: ubuntu, java_system_properties: "agent.deployment.mode=dual" in YAML, or just agent.deployment.mode=dual in the UI field.
- Call out the field-formatting gotcha explicitly: no leading -D in java_system_properties, no pasted quotes in the UI field, and no doubled outer quotes in the rendered result.
- Also call out the host-side gate: check /opt/appdynamics/appdsmartagent/profile/java/.manage/info.json. In the demo, that file should show java_system_properties as a clean key=value string before you restart the JVM and inspect the live process.
- If the UI preview and the host disagree, point to /opt/appdynamics/appdsmartagent/log.log and the Attempting to update remote config entry. That shows the actual auto_attach payload delivered to the host.
- For this demo, AppDynamics APM still goes directly to the Controller. The collector path uses the Splunk realm and access token for O11y export, not a separate AppDynamics exporter.
- For the demo, avoid implying a hot toggle on a live JVM. The docs say dynamic attachment is not supported when OpenTelemetry is enabled, so a restart after the Deployment Group change is the safe path.
- If the collector is not on the default local listener, add explicit OTEL endpoint and protocol properties. In the current lab, the default listener is already healthy on 4317 and 4318.
- Keep the app startup script plain during the demo. If you hand-edit run-app.sh or JAVA_TOOL_OPTIONS, you can accidentally hide a broken Deployment Group configuration.
- The local collector is separate from the Machine Agent. In this lab, smartagent-1 already has a healthy local collector, so use that as the steady state and rerun the idempotent helper only if you want to show the install motion.
- The message is that the file stays stable while the environment changes around it.

## Slide 14: User, Group, and Privilege Options
- Be explicit that root:root is only the lab shortcut, not the guidance for production.
- The Smart Agent installer supports setting the process identity with user and group options, and remote install also separates SSH identity from process identity.
- For remote rollout, the SSH user must own or have write access to the remote directory on the target host.
- A common demo pattern is an SSH user such as ubuntu with privilege escalation while the managed Smart Agent service runs as root:root.
- For Machine Agent, Splunk AppDynamics recommends a dedicated non-root user with read, write, and execute access to the agent home, logs, and conf directories.
- Root or administrator is still appropriate when you need privileged disk or network visibility, JVM Crash Guard access, or similar protected operations.

## Slide 15: Key Takeaways
- Close with four verbs because they are easy to remember under time pressure.
- Centralize lifecycle, attach to brownfield applications, migrate at a controlled pace, and broaden beyond Java alone.
- If the audience remembers only one thing, it should be that Smart Agent reduces the cost of change.
- That is what makes the OpenTelemetry path practical instead of theoretical.

## Slide 16: Questions and Discussion
- Open for Q and A with a few backup prompts ready in case the room is quiet.
- Be prepared to talk about remote SSH auth, rollout safety, brownfield Java attach, and dual-signal mode.
- If someone asks about runtimes not shown live, mention Node.js coverage and the broader combined-agent roadmap at the operating-model level.

## Slide 17: Continue the Discussion in Webex
- Tell attendees where to continue the conversation after the room clears.
- This slide is included because Cisco Live encourages session discussion through the mobile app and Webex spaces.
- The direct discussion URL is not available yet, so the slide points attendees to the Cisco Live mobile app and the session code instead.

## Slide 18: Complete Your Session Evaluations
- Cisco Live speaker guidance explicitly asks presenters to remind attendees to complete their evaluations.
- Keep this short and direct. Ask the room to complete the survey before they move to the next session.
- The session code is already populated so attendees can find the right survey.

## Slide 19: Thank You
- Use this as the final resting slide after questions and housekeeping.
- If needed, leave the deck here while attendees scan the survey or join the Webex discussion space.
