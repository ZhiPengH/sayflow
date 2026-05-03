import Foundation

struct TestFailure: Error, CustomStringConvertible {
    let message: String
    let file: StaticString
    let line: UInt

    var description: String {
        "\(file):\(line): \(message)"
    }
}

func expect(_ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String = "Expectation failed", file: StaticString = #file, line: UInt = #line) throws {
    if !condition() {
        throw TestFailure(message: message(), file: file, line: line)
    }
}

func expectEqual<T: Equatable>(_ actual: T, _ expected: T, file: StaticString = #file, line: UInt = #line) throws {
    if actual != expected {
        throw TestFailure(message: "Expected \(expected), got \(actual)", file: file, line: line)
    }
}

func expectNil<T>(_ value: T?, file: StaticString = #file, line: UInt = #line) throws {
    if let value {
        throw TestFailure(message: "Expected nil, got \(value)", file: file, line: line)
    }
}

func expectNotNil<T>(_ value: T?, file: StaticString = #file, line: UInt = #line) throws {
    if value == nil {
        throw TestFailure(message: "Expected non-nil value", file: file, line: line)
    }
}

func unwrap<T>(_ value: T?, file: StaticString = #file, line: UInt = #line) throws -> T {
    guard let value else {
        throw TestFailure(message: "Unexpected nil", file: file, line: line)
    }
    return value
}

struct TestCase {
    let name: String
    let run: () throws -> Void
}
