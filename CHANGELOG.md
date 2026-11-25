# Changelog

All notable changes to MCPCore. Versions follow the policy in `docs/SPEC.md`.

## Unreleased

## 1.0.0

First versioned release. Dependents move from a vendored copy of `Sources/` to this tag (`docs/UPGRADING.md`).

### Added

- `MCPProtocol`, `MCPProtocolEra` and `mcpProtocolEra(of:)`: serve MCP `2026-07-28` (per-request `_meta`) and
  `2025-11-25` (`initialize`) from one server.
- `mcpDiscoverResult`, `mcpCompleteResult`, `MCPCacheHint` and `mcpUnsupportedProtocolVersionError` for the
  `2026-07-28` revision.
- `JSONRPCError.data` (optional, omitted from JSON when nil).
- `JSONRPCErrorCode.invalidRequest`, `.internalError` and `.unsupportedProtocolVersion`.
- `docs/SPEC.md`, `docs/UPGRADING.md`, `docs/RELEASING.md`.
- CI: macOS job (Swift 6 mode), dependents build check.

### Unchanged

- Every symbol that existed before 1.0.0 keeps its signature and its JSON output.
