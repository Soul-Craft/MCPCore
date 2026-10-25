import XCTest
@testable import MCPCore

final class JSONRPCRequestTests: XCTestCase {

    func testRequest_decodesValidJSON() throws {
        let json = """
        {"jsonrpc":"2.0","id":1,"method":"tools/list","params":{"cursor":null}}
        """
        let request = try JSONDecoder().decode(JSONRPCRequest.self, from: Data(json.utf8))
        XCTAssertEqual(request.jsonrpc, "2.0")
        XCTAssertEqual(request.method, "tools/list")
        XCTAssertEqual(request.id?.intValue, 1)
        XCTAssertNotNil(request.params)
    }

    func testRequest_decodesWithStringId() throws {
        let json = """
        {"jsonrpc":"2.0","id":"abc-123","method":"initialize"}
        """
        let request = try JSONDecoder().decode(JSONRPCRequest.self, from: Data(json.utf8))
        XCTAssertEqual(request.id?.stringValue, "abc-123")
        XCTAssertNil(request.params)
    }

    func testRequest_decodesWithNullParams() throws {
        let json = """
        {"jsonrpc":"2.0","id":2,"method":"tools/list"}
        """
        let request = try JSONDecoder().decode(JSONRPCRequest.self, from: Data(json.utf8))
        XCTAssertNil(request.params)
    }

    func testRequest_decodesNotification() throws {
        let json = """
        {"jsonrpc":"2.0","method":"notifications/initialized"}
        """
        let request = try JSONDecoder().decode(JSONRPCRequest.self, from: Data(json.utf8))
        XCTAssertNil(request.id)
        XCTAssertEqual(request.method, "notifications/initialized")
    }
}

final class JSONRPCResponseTests: XCTestCase {

    func testResponse_encodesWithResult() throws {
        let response = JSONRPCResponse(
            id: .int(1),
            result: .object(["key": .string("value")]),
            error: nil
        )
        let data = try JSONEncoder().encode(response)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["jsonrpc"] as? String, "2.0")
        XCTAssertNotNil(json?["result"])
        let errorValue = json?["error"]
        XCTAssertTrue(errorValue == nil || errorValue is NSNull,
                       "Error should be nil or NSNull when not set")
    }

    func testResponse_encodesWithError() throws {
        let response = JSONRPCResponse(
            id: .int(1),
            result: nil,
            error: JSONRPCError(code: -32601, message: "Method not found")
        )
        let data = try JSONEncoder().encode(response)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let error = json?["error"] as? [String: Any]
        XCTAssertEqual(error?["code"] as? Int, -32601)
        XCTAssertEqual(error?["message"] as? String, "Method not found")
    }

    func testErrorEncodesCodeAndMessage() throws {
        let error = JSONRPCError(code: -32700, message: "Parse error")
        let data = try JSONEncoder().encode(error)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["code"] as? Int, -32700)
        XCTAssertEqual(json?["message"] as? String, "Parse error")
    }
}
