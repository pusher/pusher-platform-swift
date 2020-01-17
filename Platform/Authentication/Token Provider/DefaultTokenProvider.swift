import Foundation

/// DefaultTokenProvider makes calls to a specified HTTPS endpoint and expects to receive a OAuth 2.0
/// token from it.
///
/// This is the implementation we recommend for production use, to request tokens from your backend
/// system.
///
/// If this class does not fit your needs, you can implement the `TokenProvider` protocol yourself.
public class DefaultTokenProvider: TokenProvider {
    
    // MARK: - Types
    
    /// The closure used by the token provider in order to obtain dictionary of headers.
    public typealias HeadersInjector = () -> [String : String]?
    
    /// The closure used by the token provider in order to obtain list of query items.
    public typealias QueryItemsInjector = () -> [URLQueryItem]?
    
    /// The closure used by the token provider in order to obtain list of URL encoded body items.
    public typealias BodyInjector = () -> [URLEncodedBodyItem]?
    
    // MARK: - Properties
    
    /// The URL that will be used by the token provider to retrieve a token.
    public let url: URL
    
    /// An optional dictionary of headers to include in the request. Here you can supply the session
    /// or other credientials which your endpoint might require to authenticate the request.
    ///
    /// If not specified otherwise, the token provider will always set Content-Type header
    /// to application/x-www-form-urlencoded.
    public private(set) var headers: [String : String]?
    
    /// An optional list of query items to include in the request URL. Here you can supply any query items
    /// which your endpoint might require to process the request.
    public private(set) var queryItems: [URLQueryItem]?
    
    /// An optional list of URL encoded body items to include in the request. Here you can supply any
    /// body items which your endpoint might require to process the request.
    ///
    /// If not specified otherwise, the token provider will always add grant_type=client_credentials item
    /// to the body of the request.
    public private(set) var body: [URLEncodedBodyItem]?
    
    /// An optional closure which will be invoked when a request is about to be made, so that you can
    /// supply headers which your backend might require to process the request.
    ///
    /// If not specified otherwise, the token provider will always set Content-Type header
    /// to application/x-www-form-urlencoded.
    public var headersInjector: HeadersInjector?
    
    /// An optional closure which will be invoked when a request is about to be made, so that you can
    /// supply query items which your backend might require to process the request.
    public var queryItemsInjector: QueryItemsInjector?
    
    /// An optional closure which will be invoked when a request is about to be made, so that you can
    /// supply URL encoded body items which your backend might require to process the request.
    ///
    /// If not specified otherwise, the token provider will always add grant_type=client_credentials item
    /// to the body of the request.
    public var bodyInjector: BodyInjector?
    
    /// An optional logger used by the token provider.
    public let logger: PPLogger?
    
    // MARK: - Initializers
    
    /// Create an DefaultTokenProvider which presents either headers, query items or URL encoded body
    /// items as part of the request. These should be used to identify your application user session to your
    /// backend so that it can issue a token for the user.
    ///
    /// - Parameters:
    ///     - url: The URL to be called.
    ///     - headers: An optional dictionary of headers to include in the request. Here you can
    ///     supply the session or other credientials which your endpoint might require to authenticate
    ///     the request. If not specified otherwise, the token provider will always set Content-Type header
    ///     to application/x-www-form-urlencoded.
    ///     - queryItems: An optional list of query items to include in the request URL. Here you can
    ///     supply any query items which your endpoint might require to process the request.
    ///     - body: An optional list of URL encoded body items to include in the request. Here you can
    ///     supply any body items which your endpoint might require to process the request. If not
    ///     specified otherwise, the token provider will always add grant_type=client_credentials item
    ///     to the body of the request.
    ///     - logger: An optional logger used by the token provider.
    public init(url: URL, headers: [String : String]? = nil, queryItems: [URLQueryItem]? = nil, body: [URLEncodedBodyItem]? = nil, logger: PPLogger? = nil) {
        self.url = url
        self.headers = headers
        self.queryItems = queryItems
        self.body = body
        self.headersInjector = nil
        self.queryItemsInjector = nil
        self.bodyInjector = nil
        self.logger = logger
    }
    
    // MARK: - Token retrieval
    
    /// Method called by the SDK to authenticate the user.
    ///
    /// - Parameters:
    ///     - completionHandler: The completion handler that provides
    ///     `AuthenticationResult` to the SDK.
    public func fetchToken(completionHandler: @escaping (AuthenticationResult) -> Void) {
        self.updateRequestParametersIfNeeded()
        
        do {
            let request = try self.request()
            
            self.fetchToken(with: request, completionHandler: completionHandler)
        } catch {
            completionHandler(.failure(error: error))
        }
    }
    
    // MARK: - Private methods
    
    private func updateRequestParametersIfNeeded() {
        if let headersInjector = self.headersInjector {
            self.headers = headersInjector()
        }
        
        if let queryItemsInjector = self.queryItemsInjector {
            self.queryItems = queryItemsInjector()
        }
        
        if let bodyInjector = self.bodyInjector {
            self.body = bodyInjector()
        }
    }
    
    private func request() throws -> URLRequest {
        let requestURL = try self.requestURL(with: self.url, queryItems: self.queryItems)
        
        var request = URLRequest(url: requestURL)
        request.httpMethod = HTTPMethod.POST.rawValue
        
        let headers = self.requestHeaders(for: self.headers)
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }
        
        let body = self.requestBody(for: self.body)
        
        guard let httpBody = URLEncodedBodySerializer.serialize(body).data(using: .utf8) else {
            self.logger?.log("\(String(describing: self)) failed to build request body.", logLevel: .error)
            throw AuthenticationError.failedToSerializeBody
        }
        
        request.httpBody = httpBody
        
        return request
    }
    
    private func requestURL(with baseURL: URL, queryItems: [URLQueryItem]?) throws -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            self.logger?.log("\(String(describing: self)) failed to build request URL.", logLevel: .error)
            throw AuthenticationError.invalidURL
        }
        
        if let queryItems = self.queryItems {
            if components.queryItems != nil {
                components.queryItems?.append(contentsOf: queryItems)
            }
            else {
                components.queryItems = queryItems
            }
        }
        
        guard let requestURL = components.url else {
            self.logger?.log("\(String(describing: self)) failed to build request URL.", logLevel: .error)
            throw AuthenticationError.invalidURL
        }
        
        return requestURL
    }
    
    private func requestHeaders(for headers: [String : String]?) -> [String : String] {
        var requestHeaders = [Header.Field.contentType.rawValue : Header.Value.applicationFormURLEncoded.rawValue]
        
        headers?.forEach { field, value in
            requestHeaders[field] = value
        }
        
        return requestHeaders
    }
    
    private func requestBody(for body: [URLEncodedBodyItem]?) -> [URLEncodedBodyItem] {
        let grantType = URLEncodedBodyItem(name: URLEncodedBodyItem.Name.grantType, value: URLEncodedBodyItem.Value.clientCredentials)
        var requestBody = [grantType]
        
        if let body = body {
            let containsGrantType = body.contains { item -> Bool in
                return item.name == URLEncodedBodyItem.Name.grantType.rawValue
            }
            
            if containsGrantType {
                requestBody = body
            }
            else {
                requestBody.append(contentsOf: body)
            }
        }
        
        return requestBody
    }
    
    private func fetchToken(with request: URLRequest, completionHandler: @escaping (AuthenticationResult) -> Void) {
        if let url = request.url {
            self.logger?.log("\(String(describing: self)) will fetch token from url: \(url.absoluteString)", logLevel: .verbose)
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                self.logger?.log("\(String(describing: self)) failed to retrieve token with error: \(error.localizedDescription)", logLevel: .error)
                completionHandler(.failure(error: error))
            }
            else if let data = data, let token = try? JSONDecoder().decode(OAuthToken.self, from: data) {
                completionHandler(.authenticated(token: token))
            }
            else {
                self.logger?.log("\(String(describing: self)) failed to parse retrieved token.", logLevel: .error)
                completionHandler(.failure(error: AuthenticationError.failedToParseToken))
            }
        }.resume()
    }
    
}
