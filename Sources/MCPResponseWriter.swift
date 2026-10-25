// MCPResponseWriter.swift — Shared MCP response serialization and output
//
// Provides the common response-writing pattern used by all MCP servers:
// encode to JSON, strip embedded newlines, print to stdout, flush.

import Foundation

/// Serializes and writes a JSON-RPC response to stdout as newline-delimited JSON.
///
/// This function is NOT thread-safe on its own. Callers needing concurrent access
/// (e.g., Groups with its processing queue) should wrap calls with their own lock.
public func mcpSendResponse(_ response: JSONRPCResponse) {
    do {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(response)
        guard var jsonString = String(data: data, encoding: .utf8) else { return }

        // MCP stdio transport requires no embedded newlines
        jsonString = jsonString.replacingOccurrences(of: "\n", with: "")

        print(jsonString)
        fflush(stdout)
    } catch {
        mcpLog("mcp-core", "Error encoding response: \(error)")
    }
}

/// Converts a ToolResult into an AnyCodableValue for JSON-RPC response serialization.
public func mcpEncodeToolResult(_ toolResult: ToolResult) -> AnyCodableValue {
    var contentArray: [AnyCodableValue] = []
    for block in toolResult.content {
        switch block.type {
        case .text:
            contentArray.append(.object([
                "type": .string("text"),
                "text": .string(block.text ?? "")
            ]))
        case .image:
            if let data = block.base64Data, let mime = block.mimeType {
                contentArray.append(.object([
                    "type": .string("image"),
                    "data": .string(data),
                    "mimeType": .string(mime)
                ]))
            }
        }
    }
    return .object([
        "content": .array(contentArray),
        "isError": .bool(toolResult.isError)
    ])
}

/// Sends a tool error as a JSON-RPC success response with isError=true content.
public func mcpSendToolError(id: AnyCodableValue?, message: String) {
    let result: AnyCodableValue = .object([
        "content": .array([
            .object([
                "type": .string("text"),
                "text": .string("Error: \(message)")
            ])
        ]),
        "isError": .bool(true)
    ])

    let response = JSONRPCResponse(id: id, result: result, error: nil)
    mcpSendResponse(response)
}

/// Logs a message to stderr (visible in Claude Desktop logs).
public func mcpLog(_ prefix: String, _ message: String) {
    fputs("[\(prefix)] \(message)\n", stderr)
}
