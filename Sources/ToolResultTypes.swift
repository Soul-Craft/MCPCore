// ToolResultTypes.swift — MCP tool result content types
//
// Defines the structured result format for MCP tool calls, supporting
// mixed text and image content blocks in a single response.

/// A single content block in an MCP tool result (text or image).
public struct ToolContentBlock: Sendable {
    public enum BlockType: Sendable { case text, image }
    public let type: BlockType
    public let text: String?
    public let base64Data: String?
    public let mimeType: String?

    public static func textBlock(_ text: String) -> ToolContentBlock {
        ToolContentBlock(type: .text, text: text, base64Data: nil, mimeType: nil)
    }

    public static func imageBlock(data: String, mimeType: String) -> ToolContentBlock {
        ToolContentBlock(type: .image, text: nil, base64Data: data, mimeType: mimeType)
    }
}

/// Result from an MCP tool call, containing mixed text and image content.
public struct ToolResult: Sendable {
    public let content: [ToolContentBlock]
    public let isError: Bool

    public init(content: [ToolContentBlock], isError: Bool) {
        self.content = content
        self.isError = isError
    }

    /// Creates a text-only success result.
    public static func text(_ text: String) -> ToolResult {
        ToolResult(content: [.textBlock(text)], isError: false)
    }

    /// Creates an error result with an "Error: " prefix.
    public static func error(_ message: String) -> ToolResult {
        ToolResult(content: [.textBlock("Error: \(message)")], isError: true)
    }
}
