import Foundation

struct InstanceLocator {
    
    // MARK: - Properties
    
    private static let separator: Character = ":"
    
    let region: String
    let identifier: String
    let version: String
    
    // MARK: - Initializers
    
    init(_ instanceLocator: String) {
        let components = instanceLocator.split(separator: InstanceLocator.separator)
        
        assert(components.count == 3, "Invalid format of the provided instance locator.")
        
        self.region = String(components[1])
        self.identifier = String(components[2])
        self.version = String(components[0])
    }
    
}
