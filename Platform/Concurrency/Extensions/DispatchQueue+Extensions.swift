import Foundation

internal extension DispatchQueue {
    
    // MARK: - Initializers
    
    convenience init(for type: AnyClass) {
        var components: [String] = []
        
        let bundle = Bundle(for: type)
        assert(bundle.bundleIdentifier != nil, "Loaded main bundle without an identifier.")
        if let bundleIdentifier = bundle.bundleIdentifier {
            components.append(bundleIdentifier)
        }
        
        let name = String(describing: type.self)
        components.append(name)
        
        let label = components.joined(separator: ".")
        self.init(label: label)
    }
    
}
