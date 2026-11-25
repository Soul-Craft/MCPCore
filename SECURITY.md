# Security policy

## Reporting a vulnerability

1. Open a GitHub issue that says only that you found a security problem. Do not include technical details.
2. The repository owner follows up privately to collect the details.

GitHub private vulnerability reporting is not available on this private repository. If it is ever made public,
report through [GitHub Security Advisories](https://github.com/Soul-Craft/MCPCore/security/advisories/new) instead.

## Supported versions

| Version | Fixes |
| --- | --- |
| Latest 1.x tag | Yes |
| Older tags | No. Move to the latest 1.x tag, which is source compatible |

## Design rules

| Rule | Detail |
| --- | --- |
| Zero dependencies | Foundation and the C library only, so no third-party supply chain |
| No I/O beyond stdio | MCPCore opens no files and no network connections |
| stdout is protocol only | Logs go to stderr, so a log line cannot corrupt the JSON-RPC stream |
| Total decoding | Any JSON decodes without trapping |
| No secrets | Never log tokens, message bodies or contact details through `mcpLog` |
