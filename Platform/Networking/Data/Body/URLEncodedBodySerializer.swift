import Foundation

struct URLEncodedBodySerializer {
    
    // MARK: - Internal methods
    
    static func serialize(_ items: [URLEncodedBodyItem]) -> String {
        return items.map { "\($0.name)=\($0.value)" }.joined(separator: "&")
    }
    
}
