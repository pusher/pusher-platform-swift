import XCTest

extension String {
    
    // MARK: - Internal methods
    
    func jsonData(validate: Bool = true, file: StaticString = #file, line: UInt = #line) -> Data {
        do {
            let data = try self.data()
            if validate {
                // Verify the string is valid JSON (either a dict or an array) before returning
                _ = try jsonAny()
            }
            return data
        } catch {
            XCTFail("\(error)", file: file, line: line)
        }
        
        return Data()
    }
    
    // MARK: - Private methods
    
    private func jsonAny() throws -> Any {
        return try JSONSerialization.jsonObject(with: self.data(), options : .allowFragments)
    }
    
    private func data() throws -> Data {
        guard let data = self.data(using: .utf8) else {
            throw JSONError.conversionFailed
        }
        
        return data
    }
    
}

// MARK: - Error handling

enum JSONError: Error {
    
    case conversionFailed
    
}
