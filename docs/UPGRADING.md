# Upgrading a dependent to MCPCore v1.0.0

Until v1.0.0, each server carried a plain copy of `Sources/`. From v1.0.0 the servers depend on a tag.
On 2026-11-25 the copies in Messages, WhatsApp and Contacts were byte-identical to v1.0.0's sources before the
additions listed in the changelog, so the switch changes no behaviour.

| Repo | Copy today | Remove | Add |
| --- | --- | --- | --- |
| Messages | `MCPCore/Sources` | `MCPCore/` and the `MCPCore` target | package dependency |
| Contacts | `MCPCore/Sources` | `MCPCore/` and the `MCPCore` target | package dependency |
| WhatsApp | `MCPCore/` (a package) | `MCPCore/` and `.package(path: "../../MCPCore")` in `Apps/Groups` and `Apps/Communities` | package dependency |
| GIFMaker | none | | package dependency when its MCP server lands |

## Steps

1. Delete the vendored folder: `git rm -r MCPCore`.
2. In `Package.swift`, delete the `.target(name: "MCPCore", path: ...)` entry or the `.package(path:)` entry.
3. Add the dependency and the product:

   ```swift
   dependencies: [
       .package(url: "https://github.com/Soul-Craft/MCPCore.git", .upToNextMajor(from: "1.0.0"))
   ],
   // in each target that imports MCPCore:
   dependencies: [.product(name: "MCPCore", package: "MCPCore")]
   ```

4. Run `swift package resolve` and commit `Package.resolved`, which pins the exact tag.
5. Run the repo's own checks on the Mac (Messages: `Scripts/validate.sh`).
6. Update the repo's `CLAUDE.md` and `README.md`: MCPCore is a dependency, not a folder.

`import MCPCore` lines stay as they are. No call site changes.

## Optional in the same pull request: serve the 2026-07-28 revision

```swift
switch mcpProtocolEra(of: request) {
case .legacy:
    break // existing handling, including initialize
case .modern:
    if request.method == MCPProtocol.discoverMethod {
        return mcpDiscoverResult(name: serverName, version: serverVersion)
    }
    // handle as usual, then wrap: mcpCompleteResult(result, serverName:serverVersion:cache:)
    // pass cache: .staticList for tools/list
case .unsupportedVersion(let v):
    return JSONRPCResponse(id: request.id, result: nil, error: mcpUnsupportedProtocolVersionError(requested: v))
case .malformed:
    return JSONRPCResponse(id: request.id, result: nil,
                           error: JSONRPCError(code: JSONRPCErrorCode.invalidParams, message: "Missing required _meta fields"))
}
```

## MCPB bundles

Each server keeps shipping its own `.mcpb`. The bundle is built from a commit whose `Package.resolved` pins an
MCPCore tag, so a bundle always names the MCPCore release inside it.

## Private access

MCPCore is a private repository. On the Mac, SwiftPM fetches it with git's own credentials (the same login that
clones the dependent). A CI job that resolves packages needs a secret; see `docs/RELEASING.md`, "Private access".
