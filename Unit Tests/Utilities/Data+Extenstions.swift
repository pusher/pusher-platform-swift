import Foundation

extension Data {
    
    // MARK: - Internal methods
    
    func jsonDecoder() throws -> Decoder {
        return try JSONDecoder.default.decode(DecoderWrapper.self, from: self).decoder
    }
    
}
