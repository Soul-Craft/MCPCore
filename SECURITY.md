# Security policy

## Reporting a vulnerability

Report through [GitHub Security Advisories](https://github.com/Soul-Craft/MCPCore/security/advisories/new). Private reporting keeps the details out of public view until a fix ships.

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
