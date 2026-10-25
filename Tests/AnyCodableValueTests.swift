import XCTest
@testable import MCPCore

final class AnyCodableValueTests: XCTestCase {

    // MARK: Codable Round-Trips

    func testString_encodesAndDecodes() throws {
        let value = AnyCodableValue.string("hello")
        let decoded = try roundTrip(value)
        XCTAssertEqual(decoded.stringValue, "hello")
    }

    func testInt_encodesAndDecodes() throws {
        let value = AnyCodableValue.int(42)
        let decoded = try roundTrip(value)
        XCTAssertEqual(decoded.intValue, 42)
    }

    func testDouble_encodesAndDecodes() throws {
        let value = AnyCodableValue.double(3.14)
        let decoded = try roundTrip(value)
        if case .double(let d) = decoded {
            XCTAssertEqual(d, 3.14, accuracy: 0.001)
        } else {
            XCTFail("Expected .double, got \(decoded)")
        }
    }

    func testBool_encodesAndDecodes() throws {
        let value = AnyCodableValue.bool(true)
        let decoded = try roundTrip(value)
        XCTAssertEqual(decoded.boolValue, true)
    }

    func testNull_encodesAndDecodes() throws {
        let value = AnyCodableValue.null
        let decoded = try roundTrip(value)
        if case .null = decoded {
            // pass
        } else {
            XCTFail("Expected .null, got \(decoded)")
        }
    }

    func testArray_encodesAndDecodes() throws {
        let value = AnyCodableValue.array([.string("a"), .int(1), .bool(false)])
        let decoded = try roundTrip(value)
        if case .array(let arr) = decoded {
            XCTAssertEqual(arr.count, 3)
            XCTAssertEqual(arr[0].stringValue, "a")
            XCTAssertEqual(arr[1].intValue, 1)
            XCTAssertEqual(arr[2].boolValue, false)
        } else {
            XCTFail("Expected .array")
        }
    }

    func testObject_encodesAndDecodes() throws {
        let value = AnyCodableValue.object(["key": .string("val")])
        let decoded = try roundTrip(value)
        XCTAssertEqual(decoded.objectValue?["key"]?.stringValue, "val")
    }

    func testNestedObjectAndArray_encodesAndDecodes() throws {
        let value = AnyCodableValue.object([
            "items": .array([.int(1), .int(2)]),
            "meta": .object(["count": .int(2)])
        ])
        let decoded = try roundTrip(value)
        if case .array(let items) = decoded.objectValue?["items"] {
            XCTAssertEqual(items.count, 2)
        } else {
            XCTFail("Expected nested array")
        }
        XCTAssertEqual(decoded.objectValue?["meta"]?.objectValue?["count"]?.intValue, 2)
    }

    // MARK: Accessor Tests

    func testStringValue_returnsStringForStringCase() {
        XCTAssertEqual(AnyCodableValue.string("test").stringValue, "test")
    }

    func testStringValue_returnsNilForNonStringCase() {
        XCTAssertNil(AnyCodableValue.int(42).stringValue)
        XCTAssertNil(AnyCodableValue.bool(true).stringValue)
        XCTAssertNil(AnyCodableValue.null.stringValue)
    }

    func testIntValue_returnsIntForIntCase() {
        XCTAssertEqual(AnyCodableValue.int(99).intValue, 99)
    }

    func testIntValue_returnsIntForDoubleCase() {
        XCTAssertEqual(AnyCodableValue.double(100.0).intValue, 100)
    }

    func testIntValue_returnsNilForStringCase() {
        XCTAssertNil(AnyCodableValue.string("42").intValue)
    }

    func testBoolValue_returnsBoolForBoolCase() {
        XCTAssertEqual(AnyCodableValue.bool(true).boolValue, true)
        XCTAssertEqual(AnyCodableValue.bool(false).boolValue, false)
    }

    func testBoolValue_returnsNilForNonBoolCase() {
        XCTAssertNil(AnyCodableValue.int(1).boolValue)
        XCTAssertNil(AnyCodableValue.string("true").boolValue)
    }

    func testObjectValue_returnsDictForObjectCase() {
        let value = AnyCodableValue.object(["a": .int(1)])
        XCTAssertNotNil(value.objectValue)
        XCTAssertEqual(value.objectValue?["a"]?.intValue, 1)
    }

    func testObjectValue_returnsNilForNonObjectCase() {
        XCTAssertNil(AnyCodableValue.string("obj").objectValue)
        XCTAssertNil(AnyCodableValue.array([]).objectValue)
    }

    func testArrayValue_returnsArrayForArrayCase() {
        let value = AnyCodableValue.array([.int(1), .int(2)])
        XCTAssertEqual(value.arrayValue?.count, 2)
    }

    func testArrayValue_returnsNilForNonArrayCase() {
        XCTAssertNil(AnyCodableValue.string("arr").arrayValue)
        XCTAssertNil(AnyCodableValue.object([:]).arrayValue)
    }

    func testSubscript_returnsValueForObjectCase() {
        let value = AnyCodableValue.object(["key": .string("val")])
        XCTAssertEqual(value["key"]?.stringValue, "val")
        XCTAssertNil(value["missing"])
    }

    func testSubscript_returnsNilForNonObjectCase() {
        XCTAssertNil(AnyCodableValue.string("test")["key"])
        XCTAssertNil(AnyCodableValue.array([])["0"])
    }

    // MARK: Bool/Int Decoding Priority

    func testDecodingBoolTrue_doesNotBecomeInt1() throws {
        let json = Data("true".utf8)
        let decoded = try JSONDecoder().decode(AnyCodableValue.self, from: json)
        XCTAssertEqual(decoded.boolValue, true, "JSON true should decode as .bool, not .int")
        XCTAssertNil(decoded.intValue, "Bool true should not be accessible as intValue")
    }

    func testDecodingBoolFalse_doesNotBecomeInt0() throws {
        let json = Data("false".utf8)
        let decoded = try JSONDecoder().decode(AnyCodableValue.self, from: json)
        XCTAssertEqual(decoded.boolValue, false, "JSON false should decode as .bool, not .int")
        XCTAssertNil(decoded.intValue, "Bool false should not be accessible as intValue")
    }

    // MARK: Helper

    private func roundTrip(_ value: AnyCodableValue) throws -> AnyCodableValue {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(AnyCodableValue.self, from: data)
    }
}
