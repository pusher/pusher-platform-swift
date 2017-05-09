import Foundation

public class PPHTTPEndpointAuthorizer: PPAuthorizer {
    public var url: String

    // TODO: Seems like there is a better name for this

    public var requestInjector: ((PPHTTPEndpointAuthorizerRequest) -> (PPHTTPEndpointAuthorizerRequest))?
    public var accessToken: String? = nil
    public var refreshToken: String? = nil
    public internal(set) var accessTokenExpiresAt: Double? = nil
    public var retryStrategy: PPRetryStrategy

    public init(
        url: String,
        requestInjector: ((PPHTTPEndpointAuthorizerRequest) -> (PPHTTPEndpointAuthorizerRequest))? = nil,
        retryStrategy: PPRetryStrategy = PPDefaultRetryStrategy()
    ) {
        self.url = url
        self.requestInjector = requestInjector
        self.retryStrategy = retryStrategy
    }

    public func authorize(completionHandler: @escaping (Result<String>) -> Void) {

        // TODO: [unowned self] ?

        let retryAwareCompletionHandler = { (result: Result<String>) in
            switch result {
            case .success(let token):
                self.retryStrategy.requestSucceeded()
                completionHandler(.success(token))
            case .failure(let error):
                let shouldRetryResult = self.retryStrategy.shouldRetry(given: error)

                switch shouldRetryResult {
                case .retry(let retryWaitTimeInterval):
                    // TODO: [unowned self] here as well?

                    DispatchQueue.main.asyncAfter(deadline: .now() + retryWaitTimeInterval, execute: { [unowned self] in
                        self.authorize(completionHandler: completionHandler)
                    })
                case .doNotRetry(let reasonErr):
                    completionHandler(.failure(reasonErr))
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
        makeAuthRequest(grantType: PPEndpointRequestGrantType.clientCredentials, completionHandler: completionHandler)
    }

    public func refreshAccessToken(completionHandler: @escaping (Result<String>) -> Void) {
        makeAuthRequest(grantType: PPEndpointRequestGrantType.refreshToken, completionHandler: completionHandler)
    }

    public func makeAuthRequest(grantType: PPEndpointRequestGrantType, completionHandler: @escaping (Result<String>) -> Void) {
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
                completionHandler(.failure(PPHTTPEndpointAuthorizerError.noDataPresent))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completionHandler(.failure(PPHTTPEndpointAuthorizerError.invalidHTTPResponse(response: response, data: data)))
                return
            }

            guard 200..<300 ~= httpResponse.statusCode else {
                completionHandler(.failure(PPHTTPEndpointAuthorizerError.badResponseStatusCode(response: httpResponse, data: data)))
                return
            }

            guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) else {
                completionHandler(.failure(PPHTTPEndpointAuthorizerError.failedToDeserializeJSON(data)))
                return
            }

            guard let json = jsonObject as? [String: Any] else {
                completionHandler(.failure(PPHTTPEndpointAuthorizerError.failedToCastJSONObjectToDictionary(jsonObject)))
                return
            }

            guard let accessToken = json["access_token"] as? String else {
                completionHandler(.failure(PPHTTPEndpointAuthorizerError.validAccessTokenNotPresentInResponseJSON(json)))
                return
            }

            guard let refreshToken = json["refresh_token"] as? String else {
                completionHandler(.failure(PPHTTPEndpointAuthorizerError.validRefreshTokenNotPresentInResponseJSON(json)))
                return
            }

            // TODO: Check if Double is sensible type here
            guard let expiresIn = json["expires_in"] as? TimeInterval else {
                completionHandler(.failure(PPHTTPEndpointAuthorizerError.validExpiresInNotPresentInResponseJSON(json)))
                return
            }

            self.accessToken = accessToken
            self.refreshToken = refreshToken
            self.accessTokenExpiresAt = Date().timeIntervalSince1970 + expiresIn

            completionHandler(.success(accessToken))
        }).resume()
    }

    public func prepareAuthRequest(grantType: PPEndpointRequestGrantType) -> Result<URLRequest> {
        guard var endpointURLComponents = URLComponents(string: self.url) else {
            return .failure(PPHTTPEndpointAuthorizerError.failedToCreateURLComponents(self.url))
        }

        var httpEndpointRequest: PPHTTPEndpointAuthorizerRequest? = nil

        if requestInjector != nil {
            httpEndpointRequest = requestInjector!(PPHTTPEndpointAuthorizerRequest())
        }

        let grantBodyString = "grant_type=\(grantType.rawValue)"

        if httpEndpointRequest != nil {
            endpointURLComponents.queryItems = httpEndpointRequest!.queryItems
        }

        guard let endpointURL = endpointURLComponents.url else {
            return .failure(PPHTTPEndpointAuthorizerError.failedToCreateURLObject(endpointURLComponents))
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

public enum PPEndpointRequestGrantType: String {
    case clientCredentials = "client_credentials"
    case refreshToken = "refresh_token"
}

// TODO: This should probably be replaced by PPRequest

public class PPHTTPEndpointAuthorizerRequest {
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

// TODO: LocalizedDescription

public enum PPHTTPEndpointAuthorizerError: Error {
    case maxNumberOfRetriesReached
    case failedToCreateURLComponents(String)
    case failedToCreateURLObject(URLComponents)
    case noDataPresent
    case invalidHTTPResponse(response: URLResponse?, data: Data)
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
