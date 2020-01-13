import Foundation

struct URLEncodedBodySerializer {
    
    // MARK: - Internal methods
    
    static func serialize(_ items: [URLEncodedBodyItem]) -> String {
        return items.filter { $0.name.count > 0 }.map { "\($0.name)=\($0.value)" }.joined(separator: "&")
    }
    
}
