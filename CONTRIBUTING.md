# Contributing to Agent Dock

Thanks for your interest in improving Agent Dock!

## Development

```sh
swift build          # build
swift run AgentDock --dump   # print collected sessions without the UI
./scripts/build-app.sh --install   # build and install the .app into /Applications
```

## Guidelines

- **No personal data in the repo.** Resolve paths from
  `FileManager.default.homeDirectoryForCurrentUser` — never hardcode a username
  or an absolute path like `/Users/<name>/...` in code, comments, tests, or docs.
  Use placeholder examples such as `/Users/you/projects/example`.
- **Stay fully local.** Agent Dock does no network access and has no telemetry.
  Please keep it that way.
- **Localization.** User-facing strings go through `loc("...")` (see
  `Sources/AgentDock/L10n.swift`) with entries in both
  `Resources/en.lproj/Localizable.strings` and `Resources/ja.lproj/Localizable.strings`.
  Write source comments in English.

## Adding a new agent source

Implement the `Collector` protocol (`Sources/AgentDock/Collectors/Collector.swift`)
and register it in `AgentStore`. A collector reads a local data source and returns
`[AgentSession]` with an inferred status.
