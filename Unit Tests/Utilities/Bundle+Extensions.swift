import Foundation

extension Bundle {
    
    // MARK: - Properties
    
    static let current = Bundle(for: BundleLocator.self)
    
}

// MARK: - Bundle locator

private class BundleLocator {}
