// AnyCodableValue.swift — Type-erased Codable JSON value for MCP protocol handling
//
// Provides a unified representation of arbitrary JSON values that works with
// Swift's Codable system. Used by all MCP servers for JSON-RPC 2.0 communication.

import Foundation

/// A type-erased Codable value for handling arbitrary JSON.
///
/// JSON-RPC 2.0 has polymorphic shapes (id can be string/int/null, params is freeform)
/// that don't map well to static Codable types. This enum bridges that gap.
public enum AnyCodableValue: Codable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null
    case array([AnyCodableValue])
    case object([String: AnyCodableValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        // Bool before Int: prevents JSON true/false coercing to 1/0
        } else if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else if let i = try? container.decode(Int.self) {
            self = .int(i)
        } else if let d = try? container.decode(Double.self) {
            self = .double(d)
        } else if let s = try? container.decode(String.self) {
            self = .string(s)
        } else if let a = try? container.decode([AnyCodableValue].self) {
            self = .array(a)
        } else if let o = try? container.decode([String: AnyCodableValue].self) {
            self = .object(o)
        } else {
            self = .null
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .int(let i): try container.encode(i)
        case .double(let d): try container.encode(d)
        case .bool(let b): try container.encode(b)
        case .null: try container.encodeNil()
        case .array(let a): try container.encode(a)
        case .object(let o): try container.encode(o)
        }
    }

    /// Extracts a string value if this is a `.string` case.
    public var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    /// Extracts the dictionary if this is an `.object` case.
    public var objectValue: [String: AnyCodableValue]? {
        if case .object(let o) = self { return o }
        return nil
    }

    /// Extracts an integer value if this is an `.int` or `.double` case.
    /// Handles Claude sending integers as doubles (e.g., 100.0).
    public var intValue: Int? {
        if case .int(let i) = self { return i }
        if case .double(let d) = self { return Int(d) }
        return nil
    }

    /// Extracts a boolean value if this is a `.bool` case.
    public var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }

    /// Extracts the array if this is an `.array` case.
    public var arrayValue: [AnyCodableValue]? {
        if case .array(let a) = self { return a }
        return nil
    }

    /// Subscript access for `.object` values by key.
    public subscript(key: String) -> AnyCodableValue? {
        if case .object(let d) = self { return d[key] }
        return nil
    }
}
