import Foundation

struct DecoderWrapper: Decodable {
    
    // MARK: - Properties
    
    let decoder: Decoder
    
    // MARK: - Initializers
    
    init(from decoder: Decoder) throws {
        self.decoder = decoder
    }
}
