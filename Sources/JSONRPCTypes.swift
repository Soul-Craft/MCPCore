// JSONRPCTypes.swift — JSON-RPC 2.0 request/response envelope types
//
// These types handle the wire format for MCP stdio communication.
// Requests are decoded from client input; responses are encoded to stdout.

import Foundation

/// A JSON-RPC 2.0 request received from the client.
public struct JSONRPCRequest: Decodable, Sendable {
    public let jsonrpc: String
    public let id: AnyCodableValue?
    public let method: String
    public let params: [String: AnyCodableValue]?
}

/// A JSON-RPC 2.0 response to send to the client.
public struct JSONRPCResponse: Encodable, Sendable {
    public let jsonrpc: String
    public let id: AnyCodableValue?
    public let result: AnyCodableValue?
    public let error: JSONRPCError?

    public init(
        id: AnyCodableValue?,
        result: AnyCodableValue?,
        error: JSONRPCError?
    ) {
        self.jsonrpc = "2.0"
        self.id = id
        self.result = result
        self.error = error
    }
}

/// A JSON-RPC 2.0 error object. `data` is omitted from the JSON when nil.
public struct JSONRPCError: Encodable, Sendable {
    public let code: Int
    public let message: String
    public let data: AnyCodableValue?

    public init(code: Int, message: String, data: AnyCodableValue? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }
}
