import Foundation

struct OAuthToken: Token {
    
    // MARK: - Properties
    
    let value: String
    let expiryDate: Date
    
}

// MARK: - Decodable

extension OAuthToken: Decodable {
    
    enum CodingKeys: String, CodingKey {
        
        case value = "access_token"
        case expiryDate = "expires_in"
        
    }
    
    // MARK: - Initializers
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.value = try container.decode(String.self, forKey: .value)
        self.expiryDate = Date(timeIntervalSinceNow: try container.decode(TimeInterval.self, forKey: .expiryDate))
    }
    
}
