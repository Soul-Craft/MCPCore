import XCTest
@testable import MCPCore

final class ToolResultTypesTests: XCTestCase {

    func testTextBlock_setsTypeAndText() {
        let block = ToolContentBlock.textBlock("hello world")
        XCTAssertEqual(block.text, "hello world")
        XCTAssertNil(block.base64Data)
        XCTAssertNil(block.mimeType)
        if case .text = block.type {} else { XCTFail("Expected .text type") }
    }

    func testImageBlock_setsDataAndMimeType() {
        let block = ToolContentBlock.imageBlock(data: "abc123==", mimeType: "image/jpeg")
        XCTAssertEqual(block.base64Data, "abc123==")
        XCTAssertEqual(block.mimeType, "image/jpeg")
        XCTAssertNil(block.text)
        if case .image = block.type {} else { XCTFail("Expected .image type") }
    }

    func testToolResult_text_createsNonErrorSingleTextBlock() {
        let result = ToolResult.text("success")
        XCTAssertFalse(result.isError)
        XCTAssertEqual(result.content.count, 1)
        XCTAssertEqual(result.content[0].text, "success")
    }

    func testToolResult_error_createsErrorBlockWithPrefix() {
        let result = ToolResult.error("something failed")
        XCTAssertTrue(result.isError)
        XCTAssertEqual(result.content.count, 1)
        XCTAssertEqual(result.content[0].text, "Error: something failed")
    }

    func testToolResult_mixedContent() {
        let result = ToolResult(content: [
            .textBlock("caption"),
            .imageBlock(data: "data==", mimeType: "image/png")
        ], isError: false)
        XCTAssertEqual(result.content.count, 2)
        XCTAssertFalse(result.isError)
    }

    func testEncodeToolResult_textOnly() {
        let result = ToolResult.text("hello")
        let encoded = mcpEncodeToolResult(result)
        let content = encoded["content"]?.arrayValue
        XCTAssertEqual(content?.count, 1)
        XCTAssertEqual(content?[0]["type"]?.stringValue, "text")
        XCTAssertEqual(content?[0]["text"]?.stringValue, "hello")
        XCTAssertEqual(encoded["isError"]?.boolValue, false)
    }

    func testEncodeToolResult_withImage() {
        let result = ToolResult(content: [
            .textBlock("caption"),
            .imageBlock(data: "base64data", mimeType: "image/jpeg")
        ], isError: false)
        let encoded = mcpEncodeToolResult(result)
        let content = encoded["content"]?.arrayValue
        XCTAssertEqual(content?.count, 2)
        XCTAssertEqual(content?[1]["type"]?.stringValue, "image")
        XCTAssertEqual(content?[1]["data"]?.stringValue, "base64data")
        XCTAssertEqual(content?[1]["mimeType"]?.stringValue, "image/jpeg")
    }

    func testEncodeToolResult_error() {
        let result = ToolResult.error("bad input")
        let encoded = mcpEncodeToolResult(result)
        XCTAssertEqual(encoded["isError"]?.boolValue, true)
        XCTAssertEqual(encoded["content"]?.arrayValue?[0]["text"]?.stringValue, "Error: bad input")
    }

    func testMCPConstants_initializeResult() {
        let result = mcpInitializeResult(name: "test-server", version: "1.0.0")
        XCTAssertEqual(result["protocolVersion"]?.stringValue, "2025-11-25")
        XCTAssertEqual(result["serverInfo"]?["name"]?.stringValue, "test-server")
        XCTAssertEqual(result["serverInfo"]?["version"]?.stringValue, "1.0.0")
        XCTAssertEqual(result["capabilities"]?["tools"]?["listChanged"]?.boolValue, false)
    }

    func testMCPConstants_initializeResultWithExtraCapabilities() {
        let result = mcpInitializeResult(
            name: "test", version: "1.0.0",
            extraCapabilities: ["prompts": .object([:])]
        )
        XCTAssertNotNil(result["capabilities"]?["prompts"])
        XCTAssertNotNil(result["capabilities"]?["tools"])
    }

    func testMCPConstants_toolAnnotations() {
        let ann = mcpToolAnnotations(readOnly: true, idempotent: true)
        XCTAssertEqual(ann["readOnlyHint"]?.boolValue, true)
        XCTAssertEqual(ann["destructiveHint"]?.boolValue, false)
        XCTAssertEqual(ann["idempotentHint"]?.boolValue, true)
        XCTAssertEqual(ann["openWorldHint"]?.boolValue, false)
    }

    func testJSONRPCErrorCodes() {
        XCTAssertEqual(JSONRPCErrorCode.parseError, -32700)
        XCTAssertEqual(JSONRPCErrorCode.methodNotFound, -32601)
        XCTAssertEqual(JSONRPCErrorCode.invalidParams, -32602)
    }
}
