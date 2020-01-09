import Foundation

struct OAuthToken: Token {
    
    // MARK: - Properties
    
    let token: String
    let expiryDate: Date
    
    // MARK: - Initializers
    
    init(token: String, expiryDate: Date) {
        self.token = token
        self.expiryDate = expiryDate
    }
    
}

// MARK: - Decodable

extension OAuthToken: Decodable {
    
    enum CodingKeys: String, CodingKey {
        
        case token = "access_token"
        case expiryDate = "expires_in"
        
    }
    
    // MARK: - Initializers
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.token = try container.decode(String.self, forKey: .token)
        self.expiryDate = Date(timeIntervalSinceNow: try container.decode(TimeInterval.self, forKey: .expiryDate))
    }
    
}
