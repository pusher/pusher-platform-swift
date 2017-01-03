import Foundation

public class EndpointAuthorizer: Authorizer {
    public var url: String
    public var requestMutator: ((URLRequest) -> (URLRequest))?
    public var jwt: String? = nil

    public init(url: String, requestMutator: ((URLRequest) -> (URLRequest))? = nil) {
        self.url = url
        self.requestMutator = requestMutator
    }

    public func authorize(completionHandler: @escaping (Result<String>) -> Void) -> Void {
        // TODO: need a way to invalidate jwt being cached by the authorizer
        guard self.jwt == nil else {
            completionHandler(.success(self.jwt!))
            return
        }

        guard let endpointURL = URL(string: self.url) else {
            completionHandler(.failure(EndpointAuthorizerError.failedToCreateURLObject(self.url)))
            return
        }

        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"

        if requestMutator != nil {
            request = requestMutator!(request)
        }

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

            guard let json = jsonObject as? [String: String] else {
                completionHandler(.failure(EndpointAuthorizerError.failedToCastJSONObjectToDictionary(jsonObject)))
                return
            }

            guard let jwt = json["jwt"] else {
                completionHandler(.failure(EndpointAuthorizerError.jwtKeyNotPresentInResponseJSON(json)))
                return
            }

            self.jwt = jwt
            completionHandler(.success(jwt))
        }).resume()
    }
}

public enum EndpointAuthorizerError: Error {
    case failedToCreateURLObject(String)
    case noDataPresent
    case invalidHttpResponse(response: URLResponse?, data: Data)
    case badResponseStatusCode(response: HTTPURLResponse, data: Data)
    case failedToDeserializeJSON(Data)
    case failedToCastJSONObjectToDictionary(Any)
    case jwtKeyNotPresentInResponseJSON([String: String])
}
