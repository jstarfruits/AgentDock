# Agent Dock

A macOS menu bar app that shows the state of multiple AI agents and dev tools in one place.

日本語版は [README.ja.md](README.ja.md) をご覧ください。

It's not a task manager — the goal is a **Mission Control** for the age of AI agents.

When you're running several AI agents in parallel, it's easy to lose track of which one
is still working and which one is waiting on you, and things slip through the cracks.
Agent Dock automatically collects state from local data sources and shows:

- **Needs attention** (the agent is waiting for your input)
- **Running**
- **Idle**

in an always-on-top floating panel and in the menu bar. Click a row to jump straight back
to that app or workspace. The UI is localized in English and Japanese and follows your
system language automatically.

## Supported tools (MVP)

| Tool | Data source | What's detected |
|---|---|---|
| Claude Code | `~/.claude/sessions/*.json` + `~/.claude/projects/**/*.jsonl` | Live sessions and their state (waiting for input / running) |
| Codex | `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl` | Sessions from the last 24 hours and their state |
| VS Code | `~/.claude/ide/*.lock` | Open workspaces |

## Requirements

- macOS 14 or later
- Swift 6 toolchain (Xcode Command Line Tools)

## Usage

Build as a .app bundle and install it into /Applications (recommended):

```sh
./scripts/build-app.sh --install
```

(without `--install`, it's just produced at `build/AgentDock.app`)

To launch automatically at login, add AgentDock.app under
System Settings > General > Login Items.

You can also run it with `swift run` during development (in that case notifications go
through osascript, which has some limitations, like clicking one opening Script Editor).

- The menu bar icon shows the count of sessions needing attention
- The floating panel stays on top; drag to move it, drag an edge to resize it
  (position, size, and visibility are remembered). Use the close button to hide it,
  and "Show panel" from the menu bar to bring it back
- The panel can switch between a list view and a grid view (icon + title only)
- You get a macOS notification when an agent starts needing attention (clicking it
  brings Agent Dock to the front when running as a bundle)
- Hover a row to reveal a pin that keeps a session at the top. Needs-attention sessions
  with no update in 2 hours collapse into a "Stalled" section
- To just check the collected results in the terminal: `swift run AgentDock --dump`
- To try the focus/raise behavior on its own: `swift run AgentDock --focus <path>`

### Window-level focus (accessibility permission)

Clicking a row only **raises an existing window** — it never opens a new one.

- With accessibility permission granted: it precisely raises the window whose title
  contains the target folder name. This also works with macOS native tabs ("merge all
  windows"), selecting the matching tab
- Without permission: the first click shows a permission dialog, and until then it only
  activates the app

Grant permission under System Settings > Privacy & Security > Accessibility, for
AgentDock.app. `build-app.sh` signs every build with a stable local identity (created
automatically on first run — see [Code signing](#code-signing)), so permissions persist
across rebuilds. Running `.build/debug/AgentDock` directly during development is
unsigned, so in that case you may need to re-grant permission each time.

### Code signing

`build-app.sh` calls `scripts/ensure-signing-identity.sh` on every build, which creates
a local code-signing certificate named `Agent Dev` in your login keychain the first time
it's needed (pure `openssl` + `security`, no Apple Developer account or GUI steps
required). Signing consistently with this identity means macOS recognizes the app as the
same one after every rebuild, so Accessibility/notification permissions granted once
stay granted. Ad-hoc signing (`-s -`) has no fixed per-app identity, so each rebuild used
to look like a different app and silently revoked those permissions — that's why it's
not used here.

## Design principles

- Fully local. No network access or telemetry whatsoever
- No manual input assumed. All state is collected automatically from local files
- Collection is done via 3-second polling (FSEvents-based collection planned for later)

## Out of scope (for now)

- Integration with the Claude (claude.ai) desktop app
- Precise detection of pending permission prompts
- Distribution signed with an Apple Developer ID and notarized (currently local self-signed only)

## License

MIT License (see [LICENSE](LICENSE))
