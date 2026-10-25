# MCPCore

Shared Swift code for the Mac MCP servers: JSON-RPC message types, `AnyCodableValue`, tool-result types, stdio
helpers and media auditing. Package: `MCPCore` (Swift tools 6.2, macOS 26).

## This repo is the canonical source

The servers vendor a plain copy of `Sources/` instead of depending on this package, so each one builds on its own:

| Repo | Vendored at | Package.swift target |
|---|---|---|
| [Soul-Craft/Messages](https://github.com/Soul-Craft/Messages) | `MCPCore/Sources` | `.target(name: "MCPCore", path: "MCPCore/Sources")` |
| [Soul-Craft/WhatsApp](https://github.com/Soul-Craft/WhatsApp) | `MCPCore/` | same pattern |
| [Soul-Craft/Contacts](https://github.com/Soul-Craft/Contacts) | `MCPCore/Sources` | `.target(name: "MCPCore", path: "MCPCore/Sources")` |

On 2026-10-25 all three vendored copies were byte-identical to `Sources/` here (`diff -rq`).

## Sync rule

1. Change `Sources/` here first, with tests in `Tests/`, through a PR.
2. Then copy `Sources/` into each repo above, in one PR per repo.
3. Never edit a vendored copy directly. If a repo needs a change, it starts here.

The archived [Soul-Craft/MacApps](https://github.com/Soul-Craft/MacApps) monorepo was the original home of this code.
