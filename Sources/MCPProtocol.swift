// MCPProtocol.swift: dual-era support for MCP revisions 2026-07-28 (modern) and 2025-11-25 (legacy)
//
// The 2026-07-28 revision removed the initialize handshake. Every modern request carries
// its protocol version and client capabilities in params._meta, and servers MUST answer
// server/discover. A dual-era server keeps answering initialize for legacy clients.
// See docs/SPEC.md, "Protocol revisions", for the table this file implements.

/// Protocol revision constants and reserved `_meta` keys.
public enum MCPProtocol {
    /// The newest revision MCPCore serves (per-request `_meta`, no handshake).
    public static let modernVersion = "2026-07-28"
    /// The revision answered on `initialize` (handshake-based).
    public static let legacyVersion = mcpProtocolVersion
    /// Modern revisions this package serves, newest first.
    public static let modernVersions = [modernVersion]
    /// Every revision this package serves, newest first.
    public static let supportedVersions = [modernVersion, legacyVersion]

    /// `_meta` key carrying the request's protocol version.
    public static let protocolVersionKey = "io.modelcontextprotocol/protocolVersion"
    /// `_meta` key carrying the client's capabilities for the request.
    public static let clientCapabilitiesKey = "io.modelcontextprotocol/clientCapabilities"
    /// `_meta` key carrying the client's name and version.
    public static let clientInfoKey = "io.modelcontextprotocol/clientInfo"
    /// `_meta` key carrying the server's name and version on results.
    public static let serverInfoKey = "io.modelcontextprotocol/serverInfo"

    /// The method a modern client may call first.
    public static let discoverMethod = "server/discover"
    /// The method a legacy client calls first.
    public static let initializeMethod = "initialize"
}

/// How a server should treat one request, decided from the request alone.
public enum MCPProtocolEra: Sendable, Equatable {
    /// Handshake-based client: `initialize`, or a request with no modern `_meta`.
    case legacy
    /// Modern client on a version this package serves.
    case modern(String)
    /// Modern client on a version this package does not serve. Answer with
    /// `mcpUnsupportedProtocolVersionError(requested:)`.
    case unsupportedVersion(String)
    /// Modern request missing a required `_meta` field. Answer with `invalidParams`.
    case malformed
}

/// Classifies a request as legacy or modern per the 2026-07-28 versioning rules.
///
/// - `initialize` is always legacy.
/// - A request whose `params._meta` holds either modern key is modern; it must hold a string
///   protocol version and an object of client capabilities, otherwise it is malformed.
/// - `server/discover` without a version is malformed (it only exists in modern revisions).
/// - Anything else is legacy, which is how servers behaved before 2026-07-28.
public func mcpProtocolEra(of request: JSONRPCRequest) -> MCPProtocolEra {
    if request.method == MCPProtocol.initializeMethod { return .legacy }

    let meta = request.params?["_meta"]?.objectValue ?? [:]
    let hasModernKey = meta[MCPProtocol.protocolVersionKey] != nil || meta[MCPProtocol.clientCapabilitiesKey] != nil
    guard hasModernKey else {
        return request.method == MCPProtocol.discoverMethod ? .malformed : .legacy
    }
    guard let version = meta[MCPProtocol.protocolVersionKey]?.stringValue,
          meta[MCPProtocol.clientCapabilitiesKey]?.objectValue != nil else {
        return .malformed
    }
    return MCPProtocol.modernVersions.contains(version) ? .modern(version) : .unsupportedVersion(version)
}

/// Builds the `UnsupportedProtocolVersionError` (-32022) listing the modern versions served.
/// Legacy revisions are not listed: they are reached only through `initialize`.
public func mcpUnsupportedProtocolVersionError(requested: String) -> JSONRPCError {
    JSONRPCError(
        code: JSONRPCErrorCode.unsupportedProtocolVersion,
        message: "Unsupported protocol version",
        data: .object([
            "supported": .array(MCPProtocol.modernVersions.map { .string($0) }),
            "requested": .string(requested)
        ])
    )
}

/// Cache hint required on modern `server/discover` and list results.
public struct MCPCacheHint: Sendable, Equatable {
    public enum Scope: String, Sendable { case `public`, `private` }
    /// Freshness in milliseconds; negative values are clamped to 0.
    public let ttlMs: Int
    public let scope: Scope

    public init(ttlMs: Int, scope: Scope = .private) {
        self.ttlMs = max(0, ttlMs)
        self.scope = scope
    }

    /// Tool lists of these servers are fixed for the life of the process.
    public static let staticList = MCPCacheHint(ttlMs: 3_600_000, scope: .private)
}

/// Adds the modern result fields to a result object: `resultType: "complete"`,
/// `_meta.serverInfo`, and, when given, `ttlMs` and `cacheScope`.
///
/// Legacy clients ignore unknown fields, so the output is also safe to send to them.
/// A non-object `result` is returned unchanged.
public func mcpCompleteResult(
    _ result: AnyCodableValue,
    serverName: String,
    serverVersion: String,
    cache: MCPCacheHint? = nil
) -> AnyCodableValue {
    guard var object = result.objectValue else { return result }
    object["resultType"] = .string("complete")

    var meta = object["_meta"]?.objectValue ?? [:]
    meta[MCPProtocol.serverInfoKey] = .object([
        "name": .string(serverName),
        "version": .string(serverVersion)
    ])
    object["_meta"] = .object(meta)

    if let cache {
        object["ttlMs"] = .int(cache.ttlMs)
        object["cacheScope"] = .string(cache.scope.rawValue)
    }
    return .object(object)
}

/// Builds the `server/discover` result: supported versions, capabilities and identity.
///
/// Capabilities match `mcpInitializeResult` (tools with `listChanged: false`), merged
/// with `extraCapabilities`, so one server advertises the same features in both eras.
public func mcpDiscoverResult(
    name: String,
    version: String,
    extraCapabilities: [String: AnyCodableValue] = [:],
    instructions: String? = nil,
    cache: MCPCacheHint = .staticList
) -> AnyCodableValue {
    var capabilities: [String: AnyCodableValue] = [
        "tools": .object(["listChanged": .bool(false)])
    ]
    for (key, value) in extraCapabilities {
        capabilities[key] = value
    }

    var result: [String: AnyCodableValue] = [
        "supportedVersions": .array(MCPProtocol.modernVersions.map { .string($0) }),
        "capabilities": .object(capabilities)
    ]
    if let instructions {
        result["instructions"] = .string(instructions)
    }
    return mcpCompleteResult(.object(result), serverName: name, serverVersion: version, cache: cache)
}
