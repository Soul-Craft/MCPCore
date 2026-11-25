// MCPConstants.swift — Shared MCP protocol constants and builder helpers
//
// Provides standard error codes, the protocol version constant, and
// builder functions for common MCP response structures.

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// MCP protocol version answered on `initialize` (the legacy, handshake-based era).
/// The modern revision is `MCPProtocol.modernVersion`.
public let mcpProtocolVersion = "2025-11-25"

/// Standard JSON-RPC 2.0 error codes used by MCP servers.
public enum JSONRPCErrorCode {
    public static let parseError = -32700
    public static let invalidRequest = -32600
    public static let methodNotFound = -32601
    public static let invalidParams = -32602
    public static let internalError = -32603
    /// MCP 2026-07-28 `UnsupportedProtocolVersionError`.
    public static let unsupportedProtocolVersion = -32022
}

/// Builds a standard MCP initialize result with server info and capabilities.
///
/// All servers share the same structure: protocol version, tools capability
/// with `listChanged: false`, and server name/version. Additional capabilities
/// (e.g., prompts for Contacts) can be passed via `extraCapabilities`.
public func mcpInitializeResult(
    name: String,
    version: String,
    extraCapabilities: [String: AnyCodableValue] = [:]
) -> AnyCodableValue {
    var capabilities: [String: AnyCodableValue] = [
        "tools": .object(["listChanged": .bool(false)])
    ]
    for (key, value) in extraCapabilities {
        capabilities[key] = value
    }

    return .object([
        "protocolVersion": .string(mcpProtocolVersion),
        "capabilities": .object(capabilities),
        "serverInfo": .object([
            "name": .string(name),
            "version": .string(version)
        ])
    ])
}

/// Builds a tool annotations object for MCP tool schemas.
public func mcpToolAnnotations(
    readOnly: Bool = false,
    destructive: Bool = false,
    idempotent: Bool = false,
    openWorld: Bool = false
) -> AnyCodableValue {
    .object([
        "readOnlyHint": .bool(readOnly),
        "destructiveHint": .bool(destructive),
        "idempotentHint": .bool(idempotent),
        "openWorldHint": .bool(openWorld)
    ])
}

/// Sets up signal handling for MCP stdio servers.
/// Call at process startup to prevent SIGPIPE crashes when Claude Desktop closes the pipe.
public func mcpSetupSignalHandling() {
    signal(SIGPIPE, SIG_IGN)
}
