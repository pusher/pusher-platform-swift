import Foundation

/// A unique identifier used to identify and access Pusher's web services.
public struct InstanceLocator {
    
    // MARK: - Properties
    
    private static let separator: Character = ":"
    
    /// Region in which the instance is locatated.
    public let region: String
    
    /// Unique identifier of the instance.
    public let identifier: String
    
    /// Version of the instance.
    public let version: String
    
    // MARK: - Initializers
    
    /// Instantiates InstanceLocator from the provided string representation.
    ///
    /// If the string representation is not formatted correctly, this initializer will return nil.
    ///
    /// - Parameters:
    ///     - string: String representation of the instance locator.
    public init?(string: String) {
        let components = string.split(separator: InstanceLocator.separator)
        
        guard components.count == 3 else {
            return nil
        }
        
        self.region = String(components[1])
        self.identifier = String(components[2])
        self.version = String(components[0])
    }
    
}
