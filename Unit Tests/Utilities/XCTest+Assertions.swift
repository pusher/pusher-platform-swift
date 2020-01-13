import XCTest

// MARK: - Internal functions

func XCTAssertNoThrow<T>(_ expression: @autoclosure () throws -> T, _ message: String = "", file: StaticString = #file, line: UInt = #line, also validateResult: (T) -> Void) {
    var result: T?
    
    XCTAssertNoThrow(try executeAndAssignResult(expression, to: &result), message, file: file, line: line)
    
    if let result = result {
        validateResult(result)
    }
}

// MARK: - Private functions

private func executeAndAssignResult<T>(_ expression: @autoclosure () throws -> T?, to: inout T?) rethrows {
    to = try expression()
}
