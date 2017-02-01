import Foundation

public class HTTPEndpointAuthorizer: Authorizer {
    public var url: String
    public var requestInjector: ((HTTPEndpointAuthorizerRequest) -> (HTTPEndpointAuthorizerRequest))?
    public var accessToken: String? = nil
    public var refreshToken: String? = nil
    public internal(set) var accessTokenExpiresAt: Double? = nil

    public var maxNumberOfAttempts: Int? = 5
    public internal(set) var numberOfAttempts: Int = 0
    public var maxGapInSecondsBetweenAttempts: TimeInterval? = nil

    public init(url: String, requestInjector: ((HTTPEndpointAuthorizerRequest) -> (HTTPEndpointAuthorizerRequest))? = nil) {
        self.url = url
        self.requestInjector = requestInjector
    }

    public func authorize(completionHandler: @escaping (Result<String>) -> Void) {
        // TODO: [unowned self] ?
        let retryAwareCompletionHandler = { (result: Result<String>) in
            switch result {
            case .success(let token):
                self.numberOfAttempts = 0
                completionHandler(.success(token))
            case .failure(let err):
                self.numberOfAttempts += 1

                if self.maxNumberOfAttempts == nil || self.numberOfAttempts < self.maxNumberOfAttempts! {
                    let timeIntervalBeforeNextAttempt = TimeInterval(self.numberOfAttempts * self.numberOfAttempts)
                    let timeBeforeNextAttempt = self.maxGapInSecondsBetweenAttempts != nil ? min(timeIntervalBeforeNextAttempt, self.maxGapInSecondsBetweenAttempts!)
                                                                                           : timeIntervalBeforeNextAttempt

                    if self.maxNumberOfAttempts != nil {
                        DefaultLogger.Logger.log(message: "HTTPEndpointAuthorizer error occurred. Making attempt \(self.numberOfAttempts + 1) of \(self.maxNumberOfAttempts!) in \(timeBeforeNextAttempt)s. Error was: \(err)")
                    } else {
                        DefaultLogger.Logger.log(message: "HTTPEndpointAuthorizer error occurred. Making attempt \(self.numberOfAttempts + 1) in \(timeBeforeNextAttempt)s. Error was: \(err)")
                    }

                    // TODO: Finish all this logic
                    // TODO: [unowned self] here as well?
                    DispatchQueue.main.asyncAfter(deadline: .now() + timeBeforeNextAttempt, execute: { [unowned self] in
                        self.authorize(completionHandler: completionHandler)
                    })
                } else {
                    DefaultLogger.Logger.log(message: "Maximum number of auth attempts (\(self.maxNumberOfAttempts)) made by HTTPEndpointAuthorizer. Latest error: \(err)")
                    completionHandler(.failure(err))
                }
            }
        }

        if let token = self.accessToken, let tokenExpiryTime = self.accessTokenExpiresAt {
            guard tokenExpiryTime > Date().timeIntervalSince1970 else {
                if self.refreshToken != nil {
                    refreshAccessToken(completionHandler: retryAwareCompletionHandler)
                } else {
                    getTokenPair(completionHandler: retryAwareCompletionHandler)
                }
                // TODO: Is returning here correct?
                return
            }
            completionHandler(.success(token))
        } else {
            getTokenPair(completionHandler: retryAwareCompletionHandler)
        }
    }

    public func getTokenPair(completionHandler: @escaping (Result<String>) -> Void) {
        makeAuthRequest(grantType: EndpointRequestGrantType.clientCredentials, completionHandler: completionHandler)
    }

    public func refreshAccessToken(completionHandler: @escaping (Result<String>) -> Void) {
        makeAuthRequest(grantType: EndpointRequestGrantType.refreshToken, completionHandler: completionHandler)
    }

    public func makeAuthRequest(grantType: EndpointRequestGrantType, completionHandler: @escaping (Result<String>) -> Void) {
        let authRequestResult = prepareAuthRequest(grantType: grantType)

        guard let request = authRequestResult.value else {
            completionHandler(.failure(authRequestResult.error!))
            return
        }

        URLSession.shared.dataTask(with: request, completionHandler: { data, response, sessionError in
            if let error = sessionError {
                completionHandler(.failure(error))
                return
            }

            guard let data = data else {
                completionHandler(.failure(HTTPEndpointAuthorizerError.noDataPresent))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completionHandler(.failure(HTTPEndpointAuthorizerError.invalidHttpResponse(response: response, data: data)))
                return
            }

            guard 200..<300 ~= httpResponse.statusCode else {
                completionHandler(.failure(HTTPEndpointAuthorizerError.badResponseStatusCode(response: httpResponse, data: data)))
                return
            }

            guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) else {
                completionHandler(.failure(HTTPEndpointAuthorizerError.failedToDeserializeJSON(data)))
                return
            }

            guard let json = jsonObject as? [String: Any] else {
                completionHandler(.failure(HTTPEndpointAuthorizerError.failedToCastJSONObjectToDictionary(jsonObject)))
                return
            }

            guard let accessToken = json["access_token"] as? String else {
                completionHandler(.failure(HTTPEndpointAuthorizerError.validAccessTokenNotPresentInResponseJSON(json)))
                return
            }

            guard let refreshToken = json["refresh_token"] as? String else {
                completionHandler(.failure(HTTPEndpointAuthorizerError.validRefreshTokenNotPresentInResponseJSON(json)))
                return
            }

            // TODO: Check if Double is sensible type here
            guard let expiresIn = json["expires_in"] as? TimeInterval else {
                completionHandler(.failure(HTTPEndpointAuthorizerError.validExpiresInNotPresentInResponseJSON(json)))
                return
            }

            self.accessToken = accessToken
            self.refreshToken = refreshToken
            self.accessTokenExpiresAt = Date().timeIntervalSince1970 + expiresIn

            completionHandler(.success(accessToken))
        }).resume()
    }

    public func prepareAuthRequest(grantType: EndpointRequestGrantType) -> Result<URLRequest> {
        guard var endpointURLComponents = URLComponents(string: self.url) else {
            return .failure(HTTPEndpointAuthorizerError.failedToCreateURLComponents(self.url))
        }

        var httpEndpointRequest: HTTPEndpointAuthorizerRequest? = nil

        if requestInjector != nil {
            httpEndpointRequest = requestInjector!(HTTPEndpointAuthorizerRequest())
        }

        let grantBodyString = "grant_type=\(grantType.rawValue)"

        if httpEndpointRequest != nil {
            endpointURLComponents.queryItems = httpEndpointRequest!.queryItems
        }

        guard let endpointURL = endpointURLComponents.url else {
            return .failure(HTTPEndpointAuthorizerError.failedToCreateURLObject(endpointURLComponents))
        }

        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        if httpEndpointRequest != nil {
            for (key, val) in httpEndpointRequest!.headers {
                request.setValue(val, forHTTPHeaderField: key)
            }

            if let body = httpEndpointRequest!.body {
                let queryString = body.createPairs(nil).map({ (pair) in
                    return pair.escapedValue
                }).joined(separator: "&")

                request.httpBody = "\(grantBodyString)&\(queryString)".data(using: .utf8)
            } else {
                request.httpBody = grantBodyString.data(using: .utf8)
            }
        } else {
            request.httpBody = grantBodyString.data(using: .utf8)
        }

        return .success(request)
    }
}

public enum EndpointRequestGrantType: String {
    case clientCredentials = "client_credentials"
    case refreshToken = "refresh_token"
}

public class HTTPEndpointAuthorizerRequest {
    public var headers: [String: String] = [:]
    public var body: HTTPParameterProtocol? = nil
    public var queryItems: [URLQueryItem] = []

    public func set(headers: [String: String]) {
        self.headers = headers
    }

    public func set(body: HTTPParameterProtocol) {
        self.body = body
    }

    public func set(queryItems: [URLQueryItem]) {
        self.queryItems = queryItems
    }
}

public enum HTTPEndpointAuthorizerError: Error {
    case maxNumberOfRetriesReached
    case failedToCreateURLComponents(String)
    case failedToCreateURLObject(URLComponents)
    case noDataPresent
    case invalidHttpResponse(response: URLResponse?, data: Data)
    case badResponseStatusCode(response: HTTPURLResponse, data: Data)
    case failedToDeserializeJSON(Data)
    case failedToCastJSONObjectToDictionary(Any)
    case validAccessTokenNotPresentInResponseJSON([String: Any])
    case validRefreshTokenNotPresentInResponseJSON([String: Any])
    case validExpiresInNotPresentInResponseJSON([String: Any])
}

// Code based on SwiftHTTP https://github.com/daltoniam/SwiftHTTP
// License: Apache-2.0
// Modifications made for usage in pusher-platform-swift

/**
    This protocol is used to make the dictionary and array serializable into key/value pairs.
*/
public protocol HTTPParameterProtocol {
    func createPairs(_ key: String?) -> Array<HTTPPair>
}

/**
    Support for the Dictionary type as an HTTPParameter.
*/
extension Dictionary: HTTPParameterProtocol {
    public func createPairs(_ key: String?) -> Array<HTTPPair> {
        var collect: [HTTPPair] = []

        for (k, v) in self {
            if let nestedKey = k as? String {
                let useKey = key != nil ? "\(key!)[\(nestedKey)]" : nestedKey
                if let subParam = v as? HTTPParameterProtocol {
                    collect.append(contentsOf: subParam.createPairs(useKey))
                } else if let subParam = v as? Array<AnyObject> {
//                    // TODO: Maybe works??
//                    collect.append(contentsOf: subParam.createPairs(useKey))
                    for s in subParam.createPairs(useKey) {
                        collect.append(s)
                    }
                } else {
                    collect.append(HTTPPair(key: useKey, value: v as AnyObject))
                }
            }
        }

        return collect
    }
}

/**
    Support for the Array type as an HTTPParameter.
*/
extension Array: HTTPParameterProtocol {
    public func createPairs(_ key: String?) -> Array<HTTPPair> {
        var collect = Array<HTTPPair>()
        for v in self {
            let useKey = key != nil ? "\(key!)[]" : key
            if let subParam = v as? Dictionary<String, AnyObject> {
                collect.append(contentsOf: subParam.createPairs(useKey))
            } else if let subParam = v as? Array<AnyObject> {
                //collect.appendContentsOf(subParam.createPairs(useKey)) <- bug? should work.
                for s in subParam.createPairs(useKey) {
                    collect.append(s)
                }
            } else {
                collect.append(HTTPPair(key: useKey, value: v as AnyObject))
            }
        }
        return collect
    }
}

/**
    This is used to create key/value pairs of the parameters
*/
public struct HTTPPair {
    var key: String?
    let storeVal: AnyObject

    /**
        Create the object with a possible key and a value
    */
    init(key: String?, value: AnyObject) {
        self.key = key
        self.storeVal = value
    }

    /**
        Computed property of the string representation of the storedVal
    */
    var value: String {
        if let v = storeVal as? String {
            return v
        } else if let v = storeVal.description {
            return v
        }
        return ""
    }

    /**
        Computed property of the string representation of the storedVal escaped for URLs
    */
    var escapedValue: String {
        let allowedCharacterSet = CharacterSet(charactersIn: "!*'();:@&=+$,/?%#[]. ").inverted

        if let v = value.addingPercentEncoding(withAllowedCharacters: allowedCharacterSet) {
            if let k = key {
                if let escapedKey = k.addingPercentEncoding(withAllowedCharacters: allowedCharacterSet) {
                    return "\(escapedKey)=\(v)"
                }
            }
            return v
        }
        return ""
    }
}
