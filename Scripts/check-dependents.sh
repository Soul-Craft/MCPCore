#!/bin/bash
# Builds each dependent server against this checkout of MCPCore, so a breaking change shows up before a tag ships.
#
#   Scripts/check-dependents.sh [workdir]
#
# For each dependent it clones (or reuses) the repo under workdir (default: a temp dir), points its MCPCore at this
# checkout, then runs `swift build`. Two layouts are handled:
#   package   the dependent's Package.swift names the MCPCore package by URL: `swift package edit` swaps in this tree
#   vendored  the dependent still carries a copy (MCPCore/Sources or MCPCore/): the copy is replaced with Sources/
# Dependents link Apple frameworks (Speech, Vision, Contacts), so this runs on macOS only.
# Auth: cloning uses git's own credentials. On CI, set DEPENDENTS_READ_TOKEN (a fine-grained token with
# Contents: read on the dependent repos only); git reads it as an auth header from GIT_CONFIG_* environment
# variables, so it is never printed and never appears in a process argument list.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${1:-$(mktemp -d)}"
OWNER="Soul-Craft"
# repo:package-dir pairs. A dependent with more than one package lists each one.
DEPENDENTS=(
  "Messages:."
  "Contacts:."
  "WhatsApp:Apps/Groups"
  "WhatsApp:Apps/Communities"
)
# GIFMaker joins this list once it has a Package.swift (it builds with swiftc today and has no MCP code).

if [[ "$(uname)" != "Darwin" ]]; then
  echo "check-dependents: macOS only (dependents link Apple frameworks)" >&2
  exit 75
fi

if [[ -n "${DEPENDENTS_READ_TOKEN:-}" ]]; then
  export GIT_CONFIG_COUNT=1
  export GIT_CONFIG_KEY_0="http.https://github.com/.extraheader"
  GIT_CONFIG_VALUE_0="AUTHORIZATION: basic $(printf 'x-access-token:%s' "$DEPENDENTS_READ_TOKEN" | base64 | tr -d '\n')"
  export GIT_CONFIG_VALUE_0
fi

failed=()  # bash 3.2 (macOS) treats an empty array as unset under set -u, hence the guarded check below
for entry in "${DEPENDENTS[@]}"; do
  repo="${entry%%:*}"; dir="${entry#*:}"
  dest="$WORK/$repo"
  if [[ ! -d "$dest/.git" ]]; then
    git clone --quiet --depth 1 "https://github.com/$OWNER/$repo.git" "$dest"
  fi
  pkg="$dest/$dir"
  echo "== $repo/$dir"
  if grep -q 'MCPCore.git' "$pkg/Package.swift"; then
    (cd "$pkg" && swift package edit MCPCore --path "$ROOT" >/dev/null)
  else
    vendored=""
    if [[ -d "$dest/MCPCore/Sources" ]]; then vendored="$dest/MCPCore/Sources"; fi
    if [[ -z "$vendored" ]]; then echo "no MCPCore found in $repo" >&2; failed+=("$repo/$dir"); continue; fi
    rsync -a --delete "$ROOT/Sources/" "$vendored/"
  fi
  if ! (cd "$pkg" && swift build 2>&1 | tail -20); then
    failed+=("$repo/$dir")
  fi
done

if [[ -n "${failed[*]+x}" && ${#failed[@]} -gt 0 ]]; then
  echo "check-dependents: FAILED: ${failed[*]}" >&2
  exit 1
fi
echo "check-dependents: all dependents build against $(cd "$ROOT" && git rev-parse --short HEAD)"
