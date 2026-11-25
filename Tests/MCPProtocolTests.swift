import XCTest
@testable import MCPCore

final class MCPProtocolEraTests: XCTestCase {

    private func request(_ json: String) throws -> JSONRPCRequest {
        try JSONDecoder().decode(JSONRPCRequest.self, from: Data(json.utf8))
    }

    func testInitialize_isLegacy() throws {
        let r = try request(#"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25"}}"#)
        XCTAssertEqual(mcpProtocolEra(of: r), .legacy)
    }

    func testInitializeWithModernMeta_isStillLegacy() throws {
        let r = try request(#"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"_meta":{"io.modelcontextprotocol/protocolVersion":"2026-07-28","io.modelcontextprotocol/clientCapabilities":{}}}}"#)
        XCTAssertEqual(mcpProtocolEra(of: r), .legacy)
    }

    func testRequestWithoutMeta_isLegacy() throws {
        let r = try request(#"{"jsonrpc":"2.0","id":2,"method":"tools/list"}"#)
        XCTAssertEqual(mcpProtocolEra(of: r), .legacy)
    }

    func testMetaWithOnlyProgressToken_isLegacy() throws {
        let r = try request(#"{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"x","_meta":{"progressToken":7}}}"#)
        XCTAssertEqual(mcpProtocolEra(of: r), .legacy)
    }

    func testDiscoverWithModernMeta_isModern() throws {
        let r = try request(#"{"jsonrpc":"2.0","id":"d","method":"server/discover","params":{"_meta":{"io.modelcontextprotocol/protocolVersion":"2026-07-28","io.modelcontextprotocol/clientCapabilities":{}}}}"#)
        XCTAssertEqual(mcpProtocolEra(of: r), .modern("2026-07-28"))
    }

    func testToolsCallWithModernMeta_isModern() throws {
        let r = try request(#"{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"x","_meta":{"io.modelcontextprotocol/protocolVersion":"2026-07-28","io.modelcontextprotocol/clientCapabilities":{"extensions":{}}}}}"#)
        XCTAssertEqual(mcpProtocolEra(of: r), .modern("2026-07-28"))
    }

    func testUnknownModernVersion_isUnsupported() throws {
        let r = try request(#"{"jsonrpc":"2.0","id":4,"method":"tools/list","params":{"_meta":{"io.modelcontextprotocol/protocolVersion":"1900-01-01","io.modelcontextprotocol/clientCapabilities":{}}}}"#)
        XCTAssertEqual(mcpProtocolEra(of: r), .unsupportedVersion("1900-01-01"))
    }

    func testModernVersionWithoutCapabilities_isMalformed() throws {
        let r = try request(#"{"jsonrpc":"2.0","id":5,"method":"tools/list","params":{"_meta":{"io.modelcontextprotocol/protocolVersion":"2026-07-28"}}}"#)
        XCTAssertEqual(mcpProtocolEra(of: r), .malformed)
    }

    func testDiscoverWithoutVersion_isMalformed() throws {
        let r = try request(#"{"jsonrpc":"2.0","id":6,"method":"server/discover"}"#)
        XCTAssertEqual(mcpProtocolEra(of: r), .malformed)
    }

    func testCapabilitiesWithoutVersion_isMalformed() throws {
        let r = try request(#"{"jsonrpc":"2.0","id":7,"method":"tools/list","params":{"_meta":{"io.modelcontextprotocol/clientCapabilities":{}}}}"#)
        XCTAssertEqual(mcpProtocolEra(of: r), .malformed)
    }

    func testNonStringVersion_isMalformed() throws {
        let r = try request(#"{"jsonrpc":"2.0","id":8,"method":"tools/list","params":{"_meta":{"io.modelcontextprotocol/protocolVersion":20260728,"io.modelcontextprotocol/clientCapabilities":{}}}}"#)
        XCTAssertEqual(mcpProtocolEra(of: r), .malformed)
    }

    func testVersionConstants() {
        XCTAssertEqual(MCPProtocol.modernVersion, "2026-07-28")
        XCTAssertEqual(MCPProtocol.legacyVersion, "2025-11-25")
        XCTAssertEqual(MCPProtocol.supportedVersions, ["2026-07-28", "2025-11-25"])
    }
}

final class MCPProtocolResultTests: XCTestCase {

    private func json(_ value: some Encodable) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func testUnsupportedVersionError_shape() throws {
        let error = mcpUnsupportedProtocolVersionError(requested: "1900-01-01")
        XCTAssertEqual(error.code, -32022)
        XCTAssertEqual(error.code, JSONRPCErrorCode.unsupportedProtocolVersion)
        let obj = try json(error)
        let data = try XCTUnwrap(obj["data"] as? [String: Any])
        XCTAssertEqual(data["supported"] as? [String], ["2026-07-28"])
        XCTAssertEqual(data["requested"] as? String, "1900-01-01")
    }

    func testErrorWithoutData_omitsDataKey() throws {
        let obj = try json(JSONRPCError(code: -32601, message: "Method not found"))
        XCTAssertNil(obj["data"])
        XCTAssertEqual(obj.count, 2)
    }

    func testCompleteResult_addsResultTypeAndServerInfo() throws {
        let result = mcpCompleteResult(.object(["tools": .array([])]), serverName: "s", serverVersion: "1.0")
        let obj = try json(result)
        XCTAssertEqual(obj["resultType"] as? String, "complete")
        let meta = try XCTUnwrap(obj["_meta"] as? [String: Any])
        let info = try XCTUnwrap(meta["io.modelcontextprotocol/serverInfo"] as? [String: Any])
        XCTAssertEqual(info["name"] as? String, "s")
        XCTAssertNil(obj["ttlMs"])
        XCTAssertNil(obj["cacheScope"])
    }

    func testCompleteResult_keepsExistingMeta() throws {
        let input: AnyCodableValue = .object(["_meta": .object(["k": .int(1)])])
        let obj = try json(mcpCompleteResult(input, serverName: "s", serverVersion: "1"))
        let meta = try XCTUnwrap(obj["_meta"] as? [String: Any])
        XCTAssertEqual(meta["k"] as? Int, 1)
        XCTAssertNotNil(meta["io.modelcontextprotocol/serverInfo"])
    }

    func testCompleteResult_withCacheHint() throws {
        let result = mcpCompleteResult(.object([:]), serverName: "s", serverVersion: "1", cache: MCPCacheHint(ttlMs: 5000, scope: .public))
        let obj = try json(result)
        XCTAssertEqual(obj["ttlMs"] as? Int, 5000)
        XCTAssertEqual(obj["cacheScope"] as? String, "public")
    }

    func testCompleteResult_nonObjectUnchanged() {
        if case .string(let s) = mcpCompleteResult(.string("x"), serverName: "s", serverVersion: "1") {
            XCTAssertEqual(s, "x")
        } else {
            XCTFail("expected unchanged string")
        }
    }

    func testCacheHint_clampsNegativeTTL() {
        XCTAssertEqual(MCPCacheHint(ttlMs: -5).ttlMs, 0)
        XCTAssertEqual(MCPCacheHint.staticList.scope, .private)
    }

    func testDiscoverResult_shape() throws {
        let result = mcpDiscoverResult(
            name: "messages",
            version: "2.0.0",
            extraCapabilities: ["prompts": .object([:])],
            instructions: "Use messages to export a conversation."
        )
        let obj = try json(result)
        XCTAssertEqual(obj["supportedVersions"] as? [String], ["2026-07-28"])
        XCTAssertEqual(obj["resultType"] as? String, "complete")
        XCTAssertEqual(obj["ttlMs"] as? Int, 3_600_000)
        XCTAssertEqual(obj["cacheScope"] as? String, "private")
        XCTAssertEqual(obj["instructions"] as? String, "Use messages to export a conversation.")
        let caps = try XCTUnwrap(obj["capabilities"] as? [String: Any])
        let tools = try XCTUnwrap(caps["tools"] as? [String: Any])
        XCTAssertEqual(tools["listChanged"] as? Bool, false)
        XCTAssertNotNil(caps["prompts"])
    }

    func testDiscoverResult_omitsInstructionsWhenNil() throws {
        let obj = try json(mcpDiscoverResult(name: "n", version: "1"))
        XCTAssertNil(obj["instructions"])
    }

    func testNewErrorCodes() {
        XCTAssertEqual(JSONRPCErrorCode.invalidRequest, -32600)
        XCTAssertEqual(JSONRPCErrorCode.internalError, -32603)
    }
}
