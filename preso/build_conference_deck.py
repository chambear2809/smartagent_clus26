#!/usr/bin/env python3
from __future__ import annotations

import argparse
import copy
import zipfile
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from xml.sax.saxutils import escape
import xml.etree.ElementTree as ET


NS = {
    "a": "http://schemas.openxmlformats.org/drawingml/2006/main",
    "p": "http://schemas.openxmlformats.org/presentationml/2006/main",
    "cp": "http://schemas.openxmlformats.org/package/2006/metadata/core-properties",
    "dc": "http://purl.org/dc/elements/1.1/",
    "dcterms": "http://purl.org/dc/terms/",
    "dcmitype": "http://purl.org/dc/dcmitype/",
    "xsi": "http://www.w3.org/2001/XMLSchema-instance",
}
REL_NS = "http://schemas.openxmlformats.org/package/2006/relationships"
CONTENT_TYPES_NS = "http://schemas.openxmlformats.org/package/2006/content-types"

ET.register_namespace("a", NS["a"])
ET.register_namespace("p", NS["p"])
ET.register_namespace("cp", NS["cp"])
ET.register_namespace("dc", NS["dc"])
ET.register_namespace("dcterms", NS["dcterms"])
ET.register_namespace("dcmitype", NS["dcmitype"])
ET.register_namespace("xsi", NS["xsi"])

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_TEMPLATE = REPO_ROOT / "Cisco Live 2026 PPT Template_Dark_1772589711665001xsUU.pptx"
DEFAULT_OUTPUT = Path(__file__).resolve().parent / "smartagent-conference-short-deck.pptx"
DEFAULT_OUTLINE = Path(__file__).resolve().parent / "smartagent-conference-short-deck.md"
DEFAULT_NOTES = Path(__file__).resolve().parent / "smartagent-conference-speaker-notes.md"
DECK_TITLE = "Splunk AppDynamics Smart Agent Design and Best Practices"
DECK_SUBTITLE = "Brownfield attach, remote rollout, and a controlled path to OpenTelemetry"
SESSION_CODE = "CISCOU-2057"
SPEAKER_NAME = "Alec Chamberlain"
SPEAKER_TITLE = "Senior Staff Technical Marketing Engineer"
SESSION_ID_TEXT = f"Session ID: {SESSION_CODE}"
FOOTER_TEXT = SESSION_ID_TEXT
NOTES_TEMPLATE_XML = "ppt/notesSlides/notesSlide1.xml"


@dataclass(frozen=True)
class SlideSpec:
    source_slide: int
    title: str
    replacements: dict[str, list[str]]
    speaker_notes: list[str]


@dataclass(frozen=True)
class NoteAsset:
    deck_index: int
    source_slide: int
    note_name: str
    xml_path: str
    rels_path: str
    notes: list[str]


SLIDE_PLAN: list[SlideSpec] = [
    SlideSpec(
        source_slide=8,
        title="Splunk AppDynamics Smart Agent Design and Best Practices",
        replacements={
            "Title 6": [DECK_TITLE],
            "Text Placeholder 1": [DECK_SUBTITLE],
            "Text Placeholder 8": [SPEAKER_NAME, SPEAKER_TITLE],
            "Text Placeholder 2": [
                "Session focus",
                "Remote rollout, brownfield attach, and dual-signal migration",
            ],
            "Text Placeholder 15": [SESSION_ID_TEXT],
        },
        speaker_notes=[
            "Frame this as an operating-model story, not a feature checklist.",
            "The core message is that Smart Agent becomes the lifecycle control layer for a mixed estate.",
            "From there, teams can preserve AppDynamics workflows while adding OpenTelemetry and Splunk Observability Cloud.",
            "Tell the audience this deck is based on a live EC2 lab, so the examples are concrete rather than hypothetical.",
        ],
    ),
    SlideSpec(
        source_slide=20,
        title="Why This Story Matters",
        replacements={
            "Title 3": [
                "Why This Story Matters",
                "Brownfield estates need lifecycle control before they need another one-off agent install.",
            ],
            "Footer Placeholder 6": [SESSION_ID_TEXT],
        },
        speaker_notes=[
            "Most customers are not starting from a clean slate; they already have live applications, mixed hosts, and some AppDynamics footprint.",
            "The real friction is deployment consistency, upgrade posture, configuration drift, and uncertainty about how to adopt OpenTelemetry safely.",
            "That is why Smart Agent matters. It solves lifecycle control first and telemetry modernization second.",
            "Set the expectation that every slide after this one ties back to reducing operational friction.",
        ],
    ),
    SlideSpec(
        source_slide=17,
        title="The Problem Is Operational",
        replacements={
            "Title 4": [
                "The problem is not agent capability.",
                "It is lifecycle drift and operational sprawl.",
            ],
            "Text Placeholder 5": ["Lifecycle", "Drift", "Sprawl"],
            "Footer Placeholder 2": [FOOTER_TEXT],
        },
        speaker_notes=[
            "Emphasize that the market already has plenty of agents. Capability is not the bottleneck.",
            "The hard part is host-by-host installation, one-off configuration, and different runtime behavior across environments.",
            "Lifecycle drift means versions diverge, auto-attach settings vary, and teams lose confidence in what is actually deployed.",
            "That is why the slide reduces the problem to three words: lifecycle, drift, and sprawl.",
        ],
    ),
    SlideSpec(
        source_slide=24,
        title="What This Demo Proves",
        replacements={
            "Text Placeholder 9": ["Outcomes"],
            "Title 3": ["What This Demo Proves"],
            "TextBox 30": [
                "Centralize",
                "One control host can manage rollout and posture.",
            ],
            "TextBox 31": [
                "Attach",
                "Brownfield Java stays in place and attaches in place.",
            ],
            "TextBox 32": [
                "Migrate",
                "Add OTel signals without throwing away AppDynamics.",
            ],
            "Footer Placeholder 2": [FOOTER_TEXT],
        },
        speaker_notes=[
            "Use this slide as the thesis for the whole presentation.",
            "First, prove centralized lifecycle control from one Smart Agent host.",
            "Second, prove that brownfield Java does not need to be redesigned or relocated.",
            "Third, show that AppDynamics value and OpenTelemetry signals can coexist on the same estate.",
            "Finally, remind the audience that this is a day-two operations improvement, not just an APM demo.",
        ],
    ),
    SlideSpec(
        source_slide=47,
        title="Control Plane vs. Data Plane",
        replacements={
            "Title 2": ["Control Plane vs. Data Plane"],
            "TextBox 12": ["Control plane"],
            "TextBox 7": [
                "Deploy, start, and auto-attach from one hub.",
                "Turn fresh hosts into managed hosts remotely.",
            ],
            "TextBox 13": ["Telemetry plane"],
            "TextBox 8": [
                "Keep AppDynamics BTs and Controller workflows.",
                "Send OTLP traces and infra signals to Splunk O11y.",
            ],
            "Footer Placeholder 3": [FOOTER_TEXT],
        },
        speaker_notes=[
            "Separate lifecycle from telemetry because that makes the architecture easier to reason about.",
            "On the control-plane side, Smart Agent and smartagentctl manage install, start, attach, and posture.",
            "On the telemetry side, AppDynamics SaaS and Splunk Observability Cloud remain the destinations for the signals.",
            "This is the key migration point: teams can modernize the data plane without disrupting the lifecycle plane.",
        ],
    ),
    SlideSpec(
        source_slide=57,
        title="Six Hosts, One Story",
        replacements={
            "Text Placeholder 4": ["Lab topology"],
            "Title 2": ["Six Hosts, One Operating Model"],
            "TextBox 5": [
                "One control node runs Smart Agent and smartagentctl.",
                "One Java host proves brownfield attach with Petclinic.",
                "One Windows host is kept one version back for a live UI upgrade.",
                "One repaired infra host brings Machine Agent visibility back into the story.",
                "One reset target remains available for controlled re-enrollment.",
            ],
            "Footer Placeholder 3": [FOOTER_TEXT],
        },
        speaker_notes=[
            "Walk the room through the lab quickly and keep the emphasis on roles rather than IP addresses.",
            "The presenter only needs to operate directly from the control node, which is what makes the rollout story credible.",
            "smartagent-1 is the brownfield Java proof point, Smartagent-windows-1 is the UI-driven Windows update proof point, smartagent-3 covers repaired infrastructure, smartagent-2 stays optional Node.js breadth, and smartagent-4 is the fresh install target.",
            "The specific EC2 lab is incidental. The pattern is what should generalize to a real estate.",
        ],
    ),
    SlideSpec(
        source_slide=58,
        title="Who Wins",
        replacements={
            "Text Placeholder 4": ["Audience"],
            "Title 2": ["Who Wins"],
            "Text Placeholder 6": [
                "Operations, app, and platform teams all get something useful.",
            ],
            "TextBox 5": [
                "Operations teams get centralized rollout and upgrade posture.",
                "Application teams keep AppDynamics while adding OTel signals.",
                "Platform teams standardize config with environment variables.",
            ],
            "Footer Placeholder 3": [FOOTER_TEXT],
        },
        speaker_notes=[
            "Speak directly to the three stakeholder groups that usually evaluate this story.",
            "Operations teams care about reducing manual SSH work and turning deployment into a managed workflow.",
            "Application teams care that Business Transactions, snapshots, and Controller workflows stay intact while telemetry options expand.",
            "Platform teams care that configuration becomes standardized and portable through environment variables.",
        ],
    ),
    SlideSpec(
        source_slide=31,
        title="Demo Flow",
        replacements={
            "Text Placeholder 7": ["Demo flow"],
            "Title 2": ["From the control host to managed proof"],
            "Footer Placeholder 3": [FOOTER_TEXT],
        },
        speaker_notes=[
            "Preview the run of show so the audience understands the logic of the demo before commands start flying.",
            "Start with architecture, then open with the Windows Smart Agent upgrade in the UI.",
            "While that rollout runs, pivot into control-host configuration, then brownfield Java, and close the loop with repaired infrastructure coverage.",
            "If time gets compressed, say explicitly that Windows plus Java still proves the control-plane story, and repaired infrastructure is the extension.",
        ],
    ),
    SlideSpec(
        source_slide=43,
        title="Agent Management Upgrade Is The Wow Moment",
        replacements={
            "Title 12": ["Agent Management Upgrade Is The Wow Moment"],
            "TextBox 7": [
                "Start in Agent Management > Smart Agents.",
                "Show Smartagent-windows-1 on 26.2.0-779.",
                "Upgrade it to 26.3.0-938.",
                "Then pivot to the control host.",
            ],
            "Footer Placeholder 2": [FOOTER_TEXT],
        },
        speaker_notes=[
            "Slow down on this slide because this is the clearest live proof of central lifecycle control.",
            "Start in Agent Management > Smart Agents, show Smartagent-windows-1 on 26.2.0-779, and then start the upgrade to 26.3.0-938.",
            "Call out that the host was intentionally kept one version back so the first demo move is a visible upgrade rather than a static inventory view.",
            "The click path matters less than the operational pattern it demonstrates.",
        ],
    ),
    SlideSpec(
        source_slide=44,
        title="Agent Management Validation",
        replacements={
            "Title 12": ["Agent Management Validation"],
            "TextBox 2": [
                "Managed inventory appears in the UI.",
                "Smartagent-windows-1 visibly moves from 26.2.0-779 toward 26.3.0-938.",
                "Versioning and rollout posture become visible.",
            ],
            "Footer Placeholder 3": [FOOTER_TEXT],
        },
        speaker_notes=[
            "Move from terminal proof to UI proof. That shift is important for credibility with operations leaders.",
            "Show that the newly managed host appears with recognizable metadata and state in Agent Management.",
            "Show that Smartagent-windows-1 visibly moves from 26.2.0-779 toward 26.3.0-938.",
            "Call out that the Java process still starts normally and that the Deployment Group controls auto-attach rather than a hand-edited -javaagent startup line.",
            "Use this moment to connect the live demo to governance concerns like inventory, upgrade groups, and rollback posture.",
            "This is where the story becomes operational rather than purely technical.",
        ],
    ),
    SlideSpec(
        source_slide=49,
        title="Java, Node.js, and Infrastructure",
        replacements={
            "Title 2": ["Java, Node.js, and Infrastructure"],
            "TextBox 8": ["Application runtimes"],
            "TextBox 7": [
                "Java Petclinic is the brownfield proof.",
                "smartagent-1 now has a minimal local collector ready.",
                "Rerun the idempotent helper if you want to show install motion.",
                "Windows lifecycle is shown from Agent Management, not from RDP.",
            ],
            "TextBox 10": ["Infrastructure"],
            "TextBox 9": [
                "The collector is separate from the Machine Agent.",
                "AppD still goes directly to the Controller.",
                "Collector health is live on 13133, 4317, and 4318.",
                "Show smartagent-3 only after Machine Agent repair is validated.",
            ],
            "Footer Placeholder 3": [FOOTER_TEXT],
        },
        speaker_notes=[
            "Reinforce that Java is the critical proof point because the application already exists on the host.",
            "The latest Java dual-mode guidance says that in most cases you should run an OpenTelemetry collector on the same system as the Java Agent, and once that collector is in place the runtime JVM property is -Dagent.deployment.mode=dual.",
            "In Agent Management, the java_system_properties field expects raw key=value entries without the -D prefix and without doubled outer quotes.",
            "The UI can normalize the field and render one set of quotes after save. That is fine. The real mistake is doubled quotes from pasting quoted values into a field that already adds its own quoting.",
            "A useful demo proof point is the host-side file /opt/appdynamics/appdsmartagent/profile/java/.manage/info.json. When that file shows java_system_properties as a clean key=value string, you know the Deployment Group has reached the host before you restart the JVM.",
            "Trust info.json over the rendered field text. If auto-attach still looks off, the Smart Agent log shows the actual remote auto_attach payload the host received.",
            "In the current lab, smartagent-1 already has a minimal same-host collector installed and healthy, so the honest live story is verify it or rerun the idempotent installer helper if you want to show the install motion.",
            "The canonical operator path is the repo helper with --use-splunk-installer. Archive mode is only the restricted-egress contingency now.",
            "That helper reuses an existing package, rewrites the host to a minimal collector config, and keeps the story focused on Java dual mode rather than extra distro defaults.",
            "Also call out the operational caveat: the current docs say dynamic attachment is not supported when OpenTelemetry is enabled, so have the Deployment Group policy in place before the JVM starts or restart the JVM after the change.",
            "If you are proving Smart Agent auto-attach, keep the application startup script plain. Hand-edited JAVA_TOOL_OPTIONS can make a bad Deployment Group look correct.",
            "Be explicit that the local collector is a separate OpenTelemetry Collector process and not the Machine Agent, and that AppDynamics APM data still goes directly to the Controller.",
            "In the current lab, the local collector on smartagent-1 is already healthy on 13133, 4317, and 4318. Only put smartagent-3 on stage once the Machine Agent repair is validated.",
            "Node.js stays optional, but the operating model remains the same across runtimes.",
        ],
    ),
    SlideSpec(
        source_slide=53,
        title="The Operating Model",
        replacements={
            "Title 2": ["The Operating Model"],
            "TextBox 11": ["Two teams, one workflow"],
            "Rectangle: Rounded Corners 7": [
                "Operations",
                "Central lifecycle control",
                "Remote rollout and inventory",
            ],
            "Rectangle: Rounded Corners 8": [
                "Application owners",
                "Brownfield attach",
                "No rewrite, gradual OTel migration",
            ],
            "Footer Placeholder 3": [FOOTER_TEXT],
        },
        speaker_notes=[
            "Use this slide to summarize responsibilities instead of technology components.",
            "Operations owns lifecycle, remote rollout, and managed posture.",
            "Application owners keep service context and can change telemetry behavior without redesigning the application.",
            "The important phrase here is one workflow, because that is what lowers organizational friction.",
        ],
    ),
    SlideSpec(
        source_slide=54,
        title="Configuration Model",
        replacements={
            "Title 2": ["Configuration Model"],
            "TextBox 15": ["Three names to remember"],
            "Rectangle: Rounded Corners 4": [
                "SUPERVISOR_*",
                "Smart Agent and controller settings",
            ],
            "Rectangle: Rounded Corners 5": [
                "AGENT_DEPLOYMENT_MODE",
                "java_system_properties uses raw key=value",
                "Paste raw values into the UI",
                "Trust host proof over UI preview",
            ],
            "Rectangle: Rounded Corners 6": [
                "SPLUNK_* and OTEL_*",
                "Collector and direct-export settings",
            ],
            "Footer Placeholder 3": [FOOTER_TEXT],
        },
        speaker_notes=[
            "This is the naming slide, and it matters because naming is what makes the demo portable between labs and environments.",
            "SUPERVISOR_* covers Smart Agent and controller connectivity.",
            "The latest dual-mode docs say that in most cases you should run a local collector on the same system, and once that collector is in place the runtime JVM property is -Dagent.deployment.mode=dual.",
            "In Agent Management, java_system_properties is not pasted as JVM flags. The field expects raw key=value entries, so the concise Deployment Group example is install_agent_from: appd-portal, user: ubuntu, group: ubuntu, java_system_properties: \"agent.deployment.mode=dual\" in YAML, or just agent.deployment.mode=dual in the UI field.",
            "Call out the field-formatting gotcha explicitly: no leading -D in java_system_properties, no pasted quotes in the UI field, and no doubled outer quotes in the rendered result.",
            "Also call out the host-side gate: check /opt/appdynamics/appdsmartagent/profile/java/.manage/info.json. In the demo, that file should show java_system_properties as a clean key=value string before you restart the JVM and inspect the live process.",
            "If the UI preview and the host disagree, point to /opt/appdynamics/appdsmartagent/log.log and the Attempting to update remote config entry. That shows the actual auto_attach payload delivered to the host.",
            "For this demo, AppDynamics APM still goes directly to the Controller. The collector path uses the Splunk realm and access token for O11y export, not a separate AppDynamics exporter.",
            "For the demo, avoid implying a hot toggle on a live JVM. The docs say dynamic attachment is not supported when OpenTelemetry is enabled, so a restart after the Deployment Group change is the safe path.",
            "If the collector is not on the default local listener, add explicit OTEL endpoint and protocol properties. In the current lab, the default listener is already healthy on 4317 and 4318.",
            "Keep the app startup script plain during the demo. If you hand-edit run-app.sh or JAVA_TOOL_OPTIONS, you can accidentally hide a broken Deployment Group configuration.",
            "The local collector is separate from the Machine Agent. In this lab, smartagent-1 already has a healthy local collector, so use that as the steady state and rerun the idempotent helper only if you want to show the install motion.",
            "The message is that the file stays stable while the environment changes around it.",
        ],
    ),
    SlideSpec(
        source_slide=50,
        title="User, Group, and Privilege Options",
        replacements={
            "Title 2": ["User, Group, and Privilege Options"],
            "TextBox 8": ["Lab default"],
            "TextBox 7": [
                "We use root:root in the lab.",
                "It is the fastest demo path.",
                "It is not the only supported model.",
            ],
            "TextBox 10": ["Production options"],
            "TextBox 9": [
                "Set Smart Agent with --user and --group.",
                "Remote SSH user must own or write remote_dir.",
                "Use a dedicated service account where possible.",
            ],
            "TextBox 14": ["When root/admin is needed"],
            "TextBox 13": [
                "Service install typically starts with sudo.",
                "Machine Agent may need elevated rights for privileged metrics.",
                "Crash Guard or protected hosts can require root/admin access.",
            ],
            "Footer Placeholder 3": [FOOTER_TEXT],
        },
        speaker_notes=[
            "Be explicit that root:root is only the lab shortcut, not the guidance for production.",
            "The Smart Agent installer supports setting the process identity with user and group options, and remote install also separates SSH identity from process identity.",
            "For remote rollout, the SSH user must own or have write access to the remote directory on the target host.",
            "A common demo pattern is an SSH user such as ubuntu with privilege escalation while the managed Smart Agent service runs as root:root.",
            "For Machine Agent, Splunk AppDynamics recommends a dedicated non-root user with read, write, and execute access to the agent home, logs, and conf directories.",
            "Root or administrator is still appropriate when you need privileged disk or network visibility, JVM Crash Guard access, or similar protected operations.",
        ],
    ),
    SlideSpec(
        source_slide=55,
        title="Key Takeaways",
        replacements={
            "Title 2": ["Key Takeaways"],
            "TextBox 17": ["What the audience should leave with"],
            "Rectangle: Rounded Corners 7": [
                "Centralize",
                "One control host can manage many targets",
            ],
            "Rectangle: Rounded Corners 11": [
                "Attach",
                "Brownfield Java can be instrumented in place",
            ],
            "Rectangle: Rounded Corners 14": [
                "Migrate",
                "Dual-signal mode creates a low-risk OTel path",
            ],
            "Rectangle: Rounded Corners 15": [
                "Broaden",
                "The story extends to Windows, Node.js, and infrastructure",
            ],
            "Footer Placeholder 3": [FOOTER_TEXT],
        },
        speaker_notes=[
            "Close with four verbs because they are easy to remember under time pressure.",
            "Centralize lifecycle, attach to brownfield applications, migrate at a controlled pace, and broaden beyond Java alone.",
            "If the audience remembers only one thing, it should be that Smart Agent reduces the cost of change.",
            "The broaden point now includes Windows lifecycle changes through Agent Management, not just optional runtime coverage.",
            "That is what makes the OpenTelemetry path practical instead of theoretical.",
        ],
    ),
    SlideSpec(
        source_slide=21,
        title="Questions and Discussion",
        replacements={
            "Title 3": [
                "Questions and discussion",
                "Rollout, service accounts, brownfield attach, and dual-signal migration.",
            ],
            "Footer Placeholder 6": [SESSION_ID_TEXT],
        },
        speaker_notes=[
            "Open for Q and A with a few backup prompts ready in case the room is quiet.",
            "Be prepared to talk about remote SSH auth, rollout safety, the Windows Smart Agent upgrade flow, brownfield Java attach, and dual-signal mode.",
            "If someone asks about runtimes not shown live, mention Node.js coverage and the broader combined-agent roadmap at the operating-model level.",
        ],
    ),
    SlideSpec(
        source_slide=11,
        title="Continue the Discussion in Webex",
        replacements={
            "Title 13": ["Find this session in the Cisco Live Mobile App"],
            "Text Placeholder 15": [
                "Continue the discussion",
                "Search for CISCOU-2057 in the Cisco Live mobile app",
                "Join the Webex space when it appears",
                "Ask follow-up questions after the session",
            ],
            "Footer Placeholder 1": [SESSION_ID_TEXT],
            "Round Same Side Corner Rectangle 7": [DECK_TITLE],
            "Footer Placeholder 2": ["Direct discussion link will appear in the Cisco Live mobile app"],
            "Notes": [""],
        },
        speaker_notes=[
            "Tell attendees where to continue the conversation after the room clears.",
            "This slide is included because Cisco Live encourages session discussion through the mobile app and Webex spaces.",
            "The direct discussion URL is not available yet, so the slide points attendees to the Cisco Live mobile app and the session code instead.",
        ],
    ),
    SlideSpec(
        source_slide=67,
        title="Complete Your Session Evaluations",
        replacements={
            "Title 3": ["Complete your session evaluations"],
            "Rectangle: Rounded Corners 11": [
                "Earn",
                "100 points per survey completed",
                "and compete on the Cisco Live Challenge leaderboard.",
            ],
            "Rectangle: Rounded Corners 14": [
                "Level up",
                "and earn exclusive prizes!",
            ],
            "Rectangle: Rounded Corners 15": [
                "Complete your surveys",
                "in the Cisco Live mobile app.",
            ],
            "Rectangle: Rounded Corners 7": [
                "Complete",
                "your session survey and the overall event survey",
                "before surveys close.",
            ],
            "Footer Placeholder 1": [SESSION_ID_TEXT],
        },
        speaker_notes=[
            "Cisco Live speaker guidance explicitly asks presenters to remind attendees to complete their evaluations.",
            "Keep this short and direct. Ask the room to complete the survey before they move to the next session.",
            "The session code is already populated so attendees can find the right survey.",
        ],
    ),
    SlideSpec(
        source_slide=69,
        title="Thank You",
        replacements={
            "Title 3": ["Thank you"],
        },
        speaker_notes=[
            "Use this as the final resting slide after questions and housekeeping.",
            "If needed, leave the deck here while attendees scan the survey or join the Webex discussion space.",
        ],
    ),
]


def serialize_xml(root: ET.Element, default_namespace: str | None = None) -> bytes:
    if default_namespace is not None:
        ET.register_namespace("", default_namespace)
    return ET.tostring(root, encoding="UTF-8", xml_declaration=True)


def note_asset_for_slide(spec: SlideSpec, deck_index: int) -> NoteAsset:
    note_name = f"notesSlide{100 + deck_index}.xml"
    return NoteAsset(
        deck_index=deck_index,
        source_slide=spec.source_slide,
        note_name=note_name,
        xml_path=f"ppt/notesSlides/{note_name}",
        rels_path=f"ppt/notesSlides/_rels/{note_name}.rels",
        notes=spec.speaker_notes,
    )


def find_shape_by_name(root: ET.Element, shape_name: str) -> ET.Element:
    for shape in root.findall(".//p:sp", NS):
        props = shape.find("p:nvSpPr/p:cNvPr", NS)
        if props is not None and props.attrib.get("name") == shape_name:
            return shape
    raise KeyError(f"Shape not found: {shape_name}")


def find_shape_by_placeholder(root: ET.Element, placeholder_type: str) -> ET.Element:
    for shape in root.findall(".//p:sp", NS):
        placeholder = shape.find("p:nvSpPr/p:nvPr/p:ph", NS)
        if placeholder is not None and placeholder.attrib.get("type") == placeholder_type:
            return shape
    raise KeyError(f"Placeholder not found: {placeholder_type}")


def ensure_run(paragraph: ET.Element) -> ET.Element:
    run = paragraph.find("a:r", NS)
    if run is None:
        run = ET.Element(f"{{{NS['a']}}}r")
        ET.SubElement(run, f"{{{NS['a']}}}rPr", {"lang": "en-US"})
        paragraph.insert(0, run)
    text = run.find("a:t", NS)
    if text is None:
        text = ET.SubElement(run, f"{{{NS['a']}}}t")
    return run


def set_run_color(run_props: ET.Element, rgb_hex: str) -> None:
    for child in list(run_props):
        if child.tag.rsplit("}", 1)[-1] == "solidFill":
            run_props.remove(child)
    solid_fill = ET.SubElement(run_props, f"{{{NS['a']}}}solidFill")
    ET.SubElement(solid_fill, f"{{{NS['a']}}}srgbClr", {"val": rgb_hex})


def paragraph_template(paragraphs: list[ET.Element], index: int) -> ET.Element:
    if not paragraphs:
        return ET.Element(f"{{{NS['a']}}}p")
    return copy.deepcopy(paragraphs[min(index, len(paragraphs) - 1)])


def replace_text_in_paragraph(paragraph: ET.Element, text: str, text_color: str | None = None) -> None:
    for child in list(paragraph):
        local_name = child.tag.rsplit("}", 1)[-1]
        if local_name in {"r", "fld", "br"}:
            paragraph.remove(child)
    if not text:
        end_para = paragraph.find("a:endParaRPr", NS)
        if end_para is None:
            end_para = ET.SubElement(paragraph, f"{{{NS['a']}}}endParaRPr", {"lang": "en-US"})
        if text_color:
            set_run_color(end_para, text_color)
        return

    run = ensure_run(paragraph)
    run_props = run.find("a:rPr", NS)
    if run_props is None:
        run_props = ET.SubElement(run, f"{{{NS['a']}}}rPr", {"lang": "en-US"})
    if text_color:
        set_run_color(run_props, text_color)

    text_node = run.find("a:t", NS)
    assert text_node is not None
    text_node.text = text
    end_para = paragraph.find("a:endParaRPr", NS)
    if end_para is None:
        end_para = ET.SubElement(paragraph, f"{{{NS['a']}}}endParaRPr", {"lang": "en-US"})
    if text_color:
        set_run_color(end_para, text_color)


def set_shape_text(shape: ET.Element, paragraphs: list[str], text_color: str | None = None) -> None:
    tx_body = shape.find("p:txBody", NS)
    if tx_body is None:
        tx_body = ET.SubElement(shape, f"{{{NS['p']}}}txBody")
        ET.SubElement(tx_body, f"{{{NS['a']}}}bodyPr")
        ET.SubElement(tx_body, f"{{{NS['a']}}}lstStyle")

    body_pr = tx_body.find("a:bodyPr", NS)
    if body_pr is None:
        body_pr = ET.Element(f"{{{NS['a']}}}bodyPr")
        tx_body.insert(0, body_pr)

    for child in list(body_pr):
        if child.tag.rsplit("}", 1)[-1] in {"noAutofit", "spAutoFit", "normAutofit"}:
            body_pr.remove(child)
    body_pr.append(ET.Element(f"{{{NS['a']}}}normAutofit"))

    existing = tx_body.findall("a:p", NS)
    for paragraph in existing:
        tx_body.remove(paragraph)

    normalized = paragraphs or [""]
    for index, text in enumerate(normalized):
        paragraph = paragraph_template(existing, index)
        replace_text_in_paragraph(paragraph, text, text_color=text_color)
        tx_body.append(paragraph)


def slide_path(slide_number: int) -> str:
    return f"ppt/slides/slide{slide_number}.xml"


def slide_rels_path(slide_number: int) -> str:
    return f"ppt/slides/_rels/slide{slide_number}.xml.rels"


def render_slide(xml_bytes: bytes, spec: SlideSpec) -> bytes:
    root = ET.fromstring(xml_bytes)
    for shape_name, paragraphs in spec.replacements.items():
        shape = find_shape_by_name(root, shape_name)
        set_shape_text(shape, paragraphs, text_color="FFFFFF")
    return serialize_xml(root)


def render_presentation(xml_bytes: bytes) -> bytes:
    root = ET.fromstring(xml_bytes)
    sld_id_list = root.find("p:sldIdLst", NS)
    if sld_id_list is None:
        raise RuntimeError("presentation.xml is missing p:sldIdLst")

    existing_entries = list(sld_id_list)
    if len(existing_entries) < max(spec.source_slide for spec in SLIDE_PLAN):
        raise RuntimeError("Template presentation.xml does not contain all expected slides")

    for child in list(sld_id_list):
        sld_id_list.remove(child)

    for spec in SLIDE_PLAN:
        sld_id_list.append(copy.deepcopy(existing_entries[spec.source_slide - 1]))

    return serialize_xml(root)


def render_slide_rels(xml_bytes: bytes, note_asset: NoteAsset) -> bytes:
    root = ET.fromstring(xml_bytes)
    rel_tag = f"{{{REL_NS}}}Relationship"
    note_target = f"../notesSlides/{note_asset.note_name}"
    note_type = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/notesSlide"

    existing = root.findall(rel_tag)
    note_rel = next((rel for rel in existing if rel.attrib.get("Type") == note_type), None)
    if note_rel is None:
        next_id = 1
        for rel in existing:
            rel_id = rel.attrib.get("Id", "")
            if rel_id.startswith("rId") and rel_id[3:].isdigit():
                next_id = max(next_id, int(rel_id[3:]) + 1)
        note_rel = ET.SubElement(
            root,
            rel_tag,
            {
                "Id": f"rId{next_id}",
                "Type": note_type,
                "Target": note_target,
            },
        )
    else:
        note_rel.attrib["Target"] = note_target

    return serialize_xml(root, default_namespace=REL_NS)


def build_notes_slide(template_xml: bytes, note_asset: NoteAsset) -> bytes:
    root = ET.fromstring(template_xml)
    notes_shape = find_shape_by_placeholder(root, "body")
    set_shape_text(notes_shape, note_asset.notes)

    slide_number_shape = find_shape_by_placeholder(root, "sldNum")
    number_text = slide_number_shape.find(".//a:t", NS)
    if number_text is not None:
        number_text.text = str(note_asset.deck_index)

    return serialize_xml(root)


def build_notes_slide_rels(note_asset: NoteAsset) -> bytes:
    xml = f"""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="{REL_NS}">
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="../slides/slide{note_asset.source_slide}.xml"/>
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/notesMaster" Target="../notesMasters/notesMaster1.xml"/>
</Relationships>
"""
    return xml.encode("utf-8")


def render_content_types(xml_bytes: bytes, note_assets: list[NoteAsset]) -> bytes:
    root = ET.fromstring(xml_bytes)
    override_tag = f"{{{CONTENT_TYPES_NS}}}Override"
    existing = {
        element.attrib.get("PartName")
        for element in root.findall(override_tag)
    }

    for note_asset in note_assets:
        part_name = f"/{note_asset.xml_path}"
        if part_name in existing:
            continue
        ET.SubElement(
            root,
            override_tag,
            {
                "PartName": part_name,
                "ContentType": "application/vnd.openxmlformats-officedocument.presentationml.notesSlide+xml",
            },
        )

    return serialize_xml(root, default_namespace=CONTENT_TYPES_NS)


def build_app_xml() -> bytes:
    titles_xml = "".join(f"<vt:lpstr>{escape(spec.title)}</vt:lpstr>" for spec in SLIDE_PLAN)
    xml = f"""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
  <Application>Microsoft Macintosh PowerPoint</Application>
  <PresentationFormat>Widescreen</PresentationFormat>
  <Slides>{len(SLIDE_PLAN)}</Slides>
  <Notes>{len(SLIDE_PLAN)}</Notes>
  <HiddenSlides>0</HiddenSlides>
  <MMClips>0</MMClips>
  <ScaleCrop>false</ScaleCrop>
  <HeadingPairs>
    <vt:vector size="2" baseType="variant">
      <vt:variant><vt:lpstr>Slide Titles</vt:lpstr></vt:variant>
      <vt:variant><vt:i4>{len(SLIDE_PLAN)}</vt:i4></vt:variant>
    </vt:vector>
  </HeadingPairs>
  <TitlesOfParts>
    <vt:vector size="{len(SLIDE_PLAN)}" baseType="lpstr">
      {titles_xml}
    </vt:vector>
  </TitlesOfParts>
  <Company></Company>
  <LinksUpToDate>false</LinksUpToDate>
  <SharedDoc>false</SharedDoc>
  <HyperlinksChanged>false</HyperlinksChanged>
  <AppVersion>16.0000</AppVersion>
</Properties>
"""
    return xml.encode("utf-8")


def build_core_xml() -> bytes:
    now = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    xml = f"""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="{NS['cp']}" xmlns:dc="{NS['dc']}" xmlns:dcterms="{NS['dcterms']}" xmlns:dcmitype="{NS['dcmitype']}" xmlns:xsi="{NS['xsi']}">
  <dc:title>{escape(DECK_TITLE)}</dc:title>
  <dc:subject>Smart Agent conference deck</dc:subject>
  <dc:creator>Codex</dc:creator>
  <cp:lastModifiedBy>Codex</cp:lastModifiedBy>
  <dcterms:created xsi:type="dcterms:W3CDTF">{now}</dcterms:created>
  <dcterms:modified xsi:type="dcterms:W3CDTF">{now}</dcterms:modified>
</cp:coreProperties>
"""
    return xml.encode("utf-8")


def build_outline(outline_path: Path) -> None:
    lines = [
        "# Smart Agent Conference Deck",
        "",
        "Derived from `smartagent-architecture.md`, `smartagent-demo-script.md`, and `smartagent-lab-guide.md`.",
        "",
    ]
    for index, spec in enumerate(SLIDE_PLAN, start=1):
        lines.append(f"## Slide {index}: {spec.title}")
        for shape_name, paragraphs in spec.replacements.items():
            if shape_name.startswith("Footer"):
                continue
            if shape_name.startswith("Title") and paragraphs == [spec.title]:
                continue
            for paragraph in paragraphs:
                lines.append(f"- {paragraph}")
        lines.append("")
    outline_path.write_text("\n".join(lines), encoding="utf-8")


def build_notes_markdown(notes_path: Path) -> None:
    lines = [
        "# Smart Agent Conference Speaker Notes",
        "",
        "Speaker notes embedded in `smartagent-conference-short-deck.pptx`.",
        "",
    ]
    for index, spec in enumerate(SLIDE_PLAN, start=1):
        lines.append(f"## Slide {index}: {spec.title}")
        for paragraph in spec.speaker_notes:
            lines.append(f"- {paragraph}")
        lines.append("")
    notes_path.write_text("\n".join(lines), encoding="utf-8")


def build_deck(template_path: Path, output_path: Path, outline_path: Path, notes_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    build_outline(outline_path)
    build_notes_markdown(notes_path)

    selected_slide_files = {slide_path(spec.source_slide): spec for spec in SLIDE_PLAN}
    note_assets = [note_asset_for_slide(spec, deck_index) for deck_index, spec in enumerate(SLIDE_PLAN, start=1)]
    note_assets_by_slide_rels = {
        slide_rels_path(asset.source_slide): asset for asset in note_assets
    }

    with zipfile.ZipFile(template_path) as source, zipfile.ZipFile(output_path, "w", compression=zipfile.ZIP_DEFLATED) as target:
        notes_template_xml = source.read(NOTES_TEMPLATE_XML)

        for info in source.infolist():
            data = source.read(info.filename)

            if info.filename == "ppt/presentation.xml":
                data = render_presentation(data)
            elif info.filename in selected_slide_files:
                data = render_slide(data, selected_slide_files[info.filename])
            elif info.filename in note_assets_by_slide_rels:
                data = render_slide_rels(data, note_assets_by_slide_rels[info.filename])
            elif info.filename == "[Content_Types].xml":
                data = render_content_types(data, note_assets)
            elif info.filename == "docProps/app.xml":
                data = build_app_xml()
            elif info.filename == "docProps/core.xml":
                data = build_core_xml()

            copied = copy.copy(info)
            copied.compress_type = zipfile.ZIP_DEFLATED
            target.writestr(copied, data)

        for note_asset in note_assets:
            target.writestr(note_asset.xml_path, build_notes_slide(notes_template_xml, note_asset))
            target.writestr(note_asset.rels_path, build_notes_slide_rels(note_asset))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build the Smart Agent conference deck from the Cisco Live template.")
    parser.add_argument(
        "--template",
        type=Path,
        default=DEFAULT_TEMPLATE,
        help="Path to the source Cisco Live template PPTX.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=DEFAULT_OUTPUT,
        help="Path to write the generated PPTX.",
    )
    parser.add_argument(
        "--outline",
        type=Path,
        default=DEFAULT_OUTLINE,
        help="Path to write the markdown outline.",
    )
    parser.add_argument(
        "--notes",
        type=Path,
        default=DEFAULT_NOTES,
        help="Path to write the markdown speaker notes.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if not args.template.exists():
        raise FileNotFoundError(f"Template not found: {args.template}")
    build_deck(args.template, args.output, args.outline, args.notes)


if __name__ == "__main__":
    main()
