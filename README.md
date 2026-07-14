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
AgentDock.app (or `.build/debug/AgentDock` during development). Rebuilding changes the
code signature, so you may need to re-grant permission (toggle it off, then on again).

## Design principles

- Fully local. No network access or telemetry whatsoever
- No manual input assumed. All state is collected automatically from local files
- Collection is done via 3-second polling (FSEvents-based collection planned for later)

## Out of scope (for now)

- Integration with the Claude (claude.ai) desktop app
- Precise detection of pending permission prompts
- Distribution with a stable signature (to avoid having to re-grant accessibility permission)

## License

MIT License (see [LICENSE](LICENSE))
