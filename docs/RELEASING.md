# Releasing MCPCore

```mermaid
flowchart LR
    PR[PR merged to main] --> CI[ci: Linux on PR, macOS on main]
    CI --> RC[tag vX.Y.Z-rc1]
    RC --> D[dependents: build Messages, Contacts, WhatsApp]
    D --> T[tag vX.Y.Z]
    T --> GR[GitHub release with notes]
```

| Step | How |
| --- | --- |
| 1. Pick the number | Follow the versioning policy in `docs/SPEC.md` |
| 2. Changelog | Move `Unreleased` to the new version in `CHANGELOG.md` in the release PR |
| 3. Green on both platforms | `ci` passes on Linux for the PR and on macOS for the merge commit on `main` |
| 4. Release candidate | Tag the merge commit `vX.Y.Z-rc1`. The `dependents` workflow builds every dependent (or run `Scripts/check-dependents.sh` on the Mac) |
| 5. Release | Tag the same commit `vX.Y.Z` and publish a GitHub release whose notes are the changelog section |
| 6. Dependents | Each dependent bumps its `Package.resolved` in its own PR |

Tags are never moved or deleted. Immutable releases are on for this repository, so a published release and its
tag cannot change. A mistake ships as a new patch release.

## Private access

| Who fetches | What | Option used |
| --- | --- | --- |
| The Mac (local builds, `Scripts/check-dependents.sh`) | MCPCore and the dependents | git's own credentials. No token is stored in any repo |
| MCPCore's `dependents` workflow | Messages, Contacts, WhatsApp (read) | Secret `DEPENDENTS_READ_TOKEN`: a fine-grained token, owner Soul-Craft, Contents: read on those repos only, 1 year expiry |
| A dependent's CI, if it ever resolves packages | MCPCore (read) | Secret `MCPCORE_READ_TOKEN` in that repo: a fine-grained token with Contents: read on MCPCore only, used through `git config url.<token-url>.insteadOf https://github.com/` in the job |

Today no dependent's CI resolves packages: their CI runs static analysis only, and builds run on the Mac.
So only `DEPENDENTS_READ_TOKEN` is needed, and the workflow is skipped with a notice until it exists.
Fine-grained tokens are free and are created by the account owner at
https://github.com/settings/personal-access-tokens/new. Per-repo deploy keys were considered and not used: one key
reads one repo, so the dependents check would need three keys and SSH URLs.
