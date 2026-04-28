# Smart Agent Demo Lab

This repository contains the docs, scripts, and presentation assets for a repeatable Splunk AppDynamics Smart Agent demo lab. The workflow is built around a control host that manages private-VPC targets, a brownfield Java application, a Windows-first UI upgrade path, and a repaired infrastructure host used to show Smart Agent lifecycle control, auto-attach, and the path to OpenTelemetry and Splunk Observability Cloud.

The current material is grounded in a validated AWS `us-east-1` lab, but the repo is structured so you can adapt it to a different environment by supplying a new lab profile and credentials.

## Start Here

1. Read [`skills/smartagent-lab/SKILL.md`](skills/smartagent-lab/SKILL.md) for the repo-local workflow.
2. Copy [`skills/smartagent-lab/references/lab-profile.example.yaml`](skills/smartagent-lab/references/lab-profile.example.yaml) to a lab-specific profile and fill in your host and SSH details.
3. Copy [`smartagent-lab-credentials.example.env`](smartagent-lab-credentials.example.env) to a local untracked credentials file and source it in the shell you will use for the demo.
4. Validate the lab before rehearsal:

```bash
bash skills/smartagent-lab/scripts/validate_lab.sh --profile <copied-profile> --require-windows-demo
```

If the live flow includes infrastructure visibility on `smartagent-3`, add `--require-machine-agent`. Add `--require-java-collector` when the Java dual-signal path is part of the live flow.

## Repo Layout

- [`skills/smartagent-lab/`](skills/smartagent-lab/) contains the repo-local skill, helper scripts, fixtures, and lab references.
- [`smartagent-lab-guide.md`](smartagent-lab-guide.md) is the operator runbook for rebuilding and rehearsing the lab.
- [`smartagent-demo-script.md`](smartagent-demo-script.md) is the live 45-minute presentation script.
- [`smartagent-architecture.md`](smartagent-architecture.md) is the architecture overview and diagram.
- [`preso/`](preso/) contains the conference deck source, speaker notes, and generated slide deck.
- [`appdsmartagent_64_linux_26.3.0.938.zip`](appdsmartagent_64_linux_26.3.0.938.zip) is the staged Linux Smart Agent bundle tracked with the lab materials. Windows hosts use a separate Windows ZIP plus `smartagentctl.exe`.

## Key Scripts

- [`skills/smartagent-lab/scripts/validate_lab.sh`](skills/smartagent-lab/scripts/validate_lab.sh): read-only validation of the current lab through the control host, with optional hard gates for the Windows-first demo metadata, Java collector, and Machine Agent paths.
- [`skills/smartagent-lab/scripts/stage_bundle.sh`](skills/smartagent-lab/scripts/stage_bundle.sh): stage a Smart Agent bundle on the control host.
- [`skills/smartagent-lab/scripts/prepare_remote_push.sh`](skills/smartagent-lab/scripts/prepare_remote_push.sh): prepare managed-host install directories for remote rollout.
- [`skills/smartagent-lab/scripts/start_java_demo.sh`](skills/smartagent-lab/scripts/start_java_demo.sh): print or execute the Java brownfield demo startup flow.
- [`skills/smartagent-lab/scripts/install_local_collector.sh`](skills/smartagent-lab/scripts/install_local_collector.sh): stage and start a same-host local collector for the Java demo host.

## Operating Model

- Treat the control host as the only operator entry point.
- Reach managed Linux hosts by private VPC IP from that control host.
- Use Agent Management as the primary operator path for the opening Windows host upgrade story.
- Prefer staged and validated workflows over direct remote cutovers.
- Keep the brownfield Java app startup path plain so Smart Agent auto-attach remains the real proof point.
- Do not commit real credentials, private keys, or filled-in environment files.

## Supporting Docs

- [`skills/smartagent-lab/references/current-lab.md`](skills/smartagent-lab/references/current-lab.md): current lab-specific notes
- [`smartagent-lab-credentials.example.env`](smartagent-lab-credentials.example.env): credential template
- [`preso/smartagent-conference-short-deck.md`](preso/smartagent-conference-short-deck.md): slide source for the short deck
- [`preso/smartagent-conference-speaker-notes.md`](preso/smartagent-conference-speaker-notes.md): speaker notes for the deck
