import Foundation

public class EndpointAuthorizer: Authorizer {
    public var url: String
    public var requestMutator: ((URLRequest) -> (URLRequest))?
    public var accessToken: String? = nil
    public var refreshToken: String? = nil
    public internal(set) var accessTokenExpiresAt: Double? = nil

    // TODO: Implement
    public var maxNumberOfRetries: Int? = 3
    public internal(set) var numberOfRetries: Int = 0
    public var maxRetryGapInSeconds: TimeInterval? = nil

    public init(url: String, requestMutator: ((URLRequest) -> (URLRequest))? = nil) {
        self.url = url
        self.requestMutator = requestMutator
    }


// TODO: Implement the retry strategy - something basic like pusher-websocket-swift will be fine for now

//    guard reconnectAttemptsMax == nil || reconnectAttempts < reconnectAttemptsMax! else {
//    return
//    }
//
//    let reconnectInterval = Double(reconnectAttempts * reconnectAttempts)
//
//    let timeInterval = maxReconnectGapInSeconds != nil ? min(reconnectInterval, maxReconnectGapInSeconds!)
//        : reconnectInterval
//
//    if reconnectAttemptsMax != nil {
//    self.delegate?.debugLog?(message: "[PUSHER DEBUG] Waiting \(timeInterval) seconds before attempting to reconnect (attempt \(reconnectAttempts + 1) of \(reconnectAttemptsMax!))")
//    } else {
//    self.delegate?.debugLog?(message: "[PUSHER DEBUG] Waiting \(timeInterval) seconds before attempting to reconnect (attempt \(reconnectAttempts + 1))")
//    }
//
//    reconnectTimer = Timer.scheduledTimer(
//    timeInterval: timeInterval,
//    target: self,
//    selector: #selector(connect),
//    userInfo: nil,
//    repeats: false
//    )
//    reconnectAttempts += 1

    public func makeAuthRequest(grantType: EndpointRequestGrantType, completionHandler: @escaping (Result<String>) -> Void) {
        guard let endpointURL = URL(string: self.url) else {
            completionHandler(.failure(EndpointAuthorizerError.failedToCreateURLObject(self.url)))
            return
        }

        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        // TODO: allowing full mutation of the request is probably stupid - should just allow appending to
        // body or setting header, or maybe a query param
        // Maybe a wrapper object (AuthEndpointRequest)?
        if requestMutator != nil {
            request = requestMutator!(request)
        }

        // TODO: Check ordering of stuff here
        request.httpBody = "grant_type=\(grantType.rawValue)".data(using: .utf8)

        URLSession.shared.dataTask(with: request, completionHandler: { data, response, sessionError in
            if let error = sessionError {
                completionHandler(.failure(error))
                return
            }

            guard let data = data else {
                completionHandler(.failure(EndpointAuthorizerError.noDataPresent))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completionHandler(.failure(EndpointAuthorizerError.invalidHttpResponse(response: response, data: data)))
                return
            }

            guard 200..<300 ~= httpResponse.statusCode else {
                completionHandler(.failure(EndpointAuthorizerError.badResponseStatusCode(response: httpResponse, data: data)))
                return
            }

            guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) else {
                completionHandler(.failure(EndpointAuthorizerError.failedToDeserializeJSON(data)))
                return
            }

            guard let json = jsonObject as? [String: Any] else {
                completionHandler(.failure(EndpointAuthorizerError.failedToCastJSONObjectToDictionary(jsonObject)))
                return
            }

            guard let accessToken = json["access_token"] as? String else {
                completionHandler(.failure(EndpointAuthorizerError.validAccessTokenNotPresentInResponseJSON(json)))
                return
            }

            guard let refreshToken = json["refresh_token"] as? String else {
                completionHandler(.failure(EndpointAuthorizerError.validRefreshTokenNotPresentInResponseJSON(json)))
                return
            }

            // TODO: Check if Double is sensible type here
            guard let expiresIn = json["expires_in"] as? TimeInterval else {
                completionHandler(.failure(EndpointAuthorizerError.validExpiresInNotPresentInResponseJSON(json)))
                return
            }

            self.accessToken = accessToken
            self.refreshToken = refreshToken
            self.accessTokenExpiresAt = Date().timeIntervalSince1970 + expiresIn

            completionHandler(.success(accessToken))
        }).resume()
    }

    public func getTokenPair(completionHandler: @escaping (Result<String>) -> Void) {
        makeAuthRequest(grantType: EndpointRequestGrantType.clientCredentials, completionHandler: completionHandler)
    }

    public func refreshAccessToken(completionHandler: @escaping (Result<String>) -> Void) {
        makeAuthRequest(grantType: EndpointRequestGrantType.refreshToken, completionHandler: completionHandler)
    }

    public func authorize(completionHandler: @escaping (Result<String>) -> Void) {
        if let token = self.accessToken, let tokenExpiryTime = self.accessTokenExpiresAt {
            guard tokenExpiryTime > Date().timeIntervalSince1970 else {
                if self.refreshToken != nil {
                    refreshAccessToken(completionHandler: completionHandler)
                } else {
                    getTokenPair(completionHandler: completionHandler)
                }
                // TODO: Is returning here correct?
                return
            }
            completionHandler(.success(token))
        } else {
            getTokenPair(completionHandler: completionHandler)
        }
    }
}

public enum EndpointRequestGrantType: String {
    case clientCredentials = "client_credentials"
    case refreshToken = "refresh_token"
}

public enum EndpointAuthorizerError: Error {
    case failedToCreateURLObject(String)
    case noDataPresent
    case invalidHttpResponse(response: URLResponse?, data: Data)
    case badResponseStatusCode(response: HTTPURLResponse, data: Data)
    case failedToDeserializeJSON(Data)
    case failedToCastJSONObjectToDictionary(Any)
    case validAccessTokenNotPresentInResponseJSON([String: Any])
    case validRefreshTokenNotPresentInResponseJSON([String: Any])
    case validExpiresInNotPresentInResponseJSON([String: Any])
}
