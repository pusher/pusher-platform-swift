import Foundation

public class PPHTTPEndpointTokenProvider: PPAuthorizer {
    public var url: String

    // TODO: Seems like there is a better name for this

    public var requestInjector: ((PPHTTPEndpointTokenProviderRequest) -> (PPHTTPEndpointTokenProviderRequest))?
    public var accessToken: String? = nil
    public var refreshToken: String? = nil
    public internal(set) var accessTokenExpiresAt: Double? = nil
    public var retryStrategy: PPRetryStrategy

    public init(
        url: String,
        requestInjector: ((PPHTTPEndpointTokenProviderRequest) -> (PPHTTPEndpointTokenProviderRequest))? = nil,
        retryStrategy: PPRetryStrategy = PPDefaultRetryStrategy()
    ) {
        self.url = url
        self.requestInjector = requestInjector
        self.retryStrategy = retryStrategy
    }

    public func fetchToken(completionHandler: @escaping (PPAuthorizerResult) -> Void) {

        // TODO: [unowned self] ?

        let retryAwareCompletionHandler = { (tokenProviderResult: PPAuthorizerResult) in
            switch tokenProviderResult {
            case .error(let err):
                let shouldRetryResult = self.retryStrategy.shouldRetry(given: err)

                switch shouldRetryResult {
                case .retry(let retryWaitTimeInterval):
                    // TODO: [unowned self] here as well?

                    DispatchQueue.main.asyncAfter(deadline: .now() + retryWaitTimeInterval, execute: { [unowned self] in
                        self.fetchToken(completionHandler: completionHandler)
                    })
                case .doNotRetry(let reasonErr):
                    completionHandler(PPAuthorizerResult.error(error: reasonErr))
                }
                return
            case .success(let token):
                self.retryStrategy.requestSucceeded()
                completionHandler(PPAuthorizerResult.success(token: token))
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
            completionHandler(PPAuthorizerResult.success(token: token))
        } else {
            getTokenPair(completionHandler: retryAwareCompletionHandler)
        }
    }

    public func getTokenPair(completionHandler: @escaping (PPAuthorizerResult) -> Void) {
        makeAuthRequest(grantType: PPEndpointRequestGrantType.clientCredentials, completionHandler: completionHandler)
    }

    public func refreshAccessToken(completionHandler: @escaping (PPAuthorizerResult) -> Void) {
        makeAuthRequest(grantType: PPEndpointRequestGrantType.refreshToken, completionHandler: completionHandler)
    }

    public func makeAuthRequest(grantType: PPEndpointRequestGrantType, completionHandler: @escaping (PPAuthorizerResult) -> Void) {
        let authRequestResult = prepareAuthRequest(grantType: grantType)

        guard let request = authRequestResult.request, authRequestResult.error == nil else {
            completionHandler(PPAuthorizerResult.error(error: authRequestResult.error!))
            return
        }

        URLSession.shared.dataTask(with: request, completionHandler: { data, response, sessionError in
            if let error = sessionError {
                completionHandler(PPAuthorizerResult.error(error: error))
                return
            }

            guard let data = data else {
                completionHandler(PPAuthorizerResult.error(error: PPHTTPEndpointTokenProviderError.noDataPresent))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completionHandler(PPAuthorizerResult.error(error: PPHTTPEndpointTokenProviderError.invalidHTTPResponse(response: response, data: data)))
                return
            }

            guard 200..<300 ~= httpResponse.statusCode else {
                completionHandler(PPAuthorizerResult.error(error: PPHTTPEndpointTokenProviderError.badResponseStatusCode(response: httpResponse, data: data)))
                return
            }

            guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) else {
                completionHandler(PPAuthorizerResult.error(error: PPHTTPEndpointTokenProviderError.failedToDeserializeJSON(data)))
                return
            }

            guard let json = jsonObject as? [String: Any] else {
                completionHandler(PPAuthorizerResult.error(error: PPHTTPEndpointTokenProviderError.failedToCastJSONObjectToDictionary(jsonObject)))
                return
            }

            guard let accessToken = json["access_token"] as? String else {
                completionHandler(PPAuthorizerResult.error(error: PPHTTPEndpointTokenProviderError.validAccessTokenNotPresentInResponseJSON(json)))
                return
            }

            guard let refreshToken = json["refresh_token"] as? String else {
                completionHandler(PPAuthorizerResult.error(error: PPHTTPEndpointTokenProviderError.validRefreshTokenNotPresentInResponseJSON(json)))
                return
            }

            // TODO: Check if Double is sensible type here
            guard let expiresIn = json["expires_in"] as? TimeInterval else {
                completionHandler(PPAuthorizerResult.error(error: PPHTTPEndpointTokenProviderError.validExpiresInNotPresentInResponseJSON(json)))
                return
            }

            self.accessToken = accessToken
            self.refreshToken = refreshToken
            self.accessTokenExpiresAt = Date().timeIntervalSince1970 + expiresIn

            completionHandler(PPAuthorizerResult.success(token: accessToken))
        }).resume()
    }

    public func prepareAuthRequest(grantType: PPEndpointRequestGrantType) -> (request: URLRequest?, error: Error?) {
        guard var endpointURLComponents = URLComponents(string: self.url) else {
            return (request: nil, error: PPHTTPEndpointTokenProviderError.failedToCreateURLComponents(self.url))
        }

        var httpEndpointRequest: PPHTTPEndpointTokenProviderRequest? = nil

        if requestInjector != nil {
            httpEndpointRequest = requestInjector!(PPHTTPEndpointTokenProviderRequest())
        }

        let grantBodyString = "grant_type=\(grantType.rawValue)"

        if httpEndpointRequest != nil {
            endpointURLComponents.queryItems = httpEndpointRequest!.queryItems
        }

        guard let endpointURL = endpointURLComponents.url else {
            return (request: nil, error: PPHTTPEndpointTokenProviderError.failedToCreateURLObject(endpointURLComponents))
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

        return (request: request, error: nil)
    }
}

public enum PPEndpointRequestGrantType: String {
    case clientCredentials = "client_credentials"
    case refreshToken = "refresh_token"
}

// TODO: This should probably be replaced by PPRequestOptions

public class PPHTTPEndpointTokenProviderRequest {
    public var headers: [String: String] = [:]
    public var body: HTTPParameterProtocol? = nil
    public var queryItems: [URLQueryItem] = []

    // If a header key already exists then calling this will override it
    public func addHeaders(_ newHeaders: [String: String]) {
        for header in newHeaders {
            self.headers[header.key] = header.value
        }
    }

    public func addQueryItems(_ newQueryItems: [URLQueryItem]) {
        self.queryItems.append(contentsOf: newQueryItems)
    }
}

// TODO: LocalizedDescription

public enum PPHTTPEndpointTokenProviderError: Error {
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
