//
//  EndpointAuthorizer.swift
//  ElementsSwift
//
//  Created by Hamilton Chapman on 05/10/2016.
//
//

import PromiseKit

public class EndpointAuthorizer: Authorizer {
    public var url: String
    public var requestMutator: ((URLRequest) -> (URLRequest))?
    public var jwt: String? = nil

    public init(url: String, requestMutator: ((URLRequest) -> (URLRequest))? = nil) {
        self.url = url
        self.requestMutator = requestMutator
    }

    public func authorize() -> Promise<String> {
        // TODO: need a way to invalidate jwt being cached by the authorizer
        if jwt != nil {
            return Promise { resolve, reject in
                resolve(self.jwt!)
            }
        } else {
            return Promise { fulfill, reject in
                var request = URLRequest(url: URL(string: url)!)
                request.httpMethod = "POST"

                // TODO: Why is this an empty string?
                request.httpBody = "".data(using: String.Encoding.utf8)

                if requestMutator != nil {
                    request = requestMutator!(request)
                }

                URLSession.shared.dataTask(with: request, completionHandler: { data, response, sessionError in
                    if let error = sessionError {
                        reject(error)
                        return
                    }

                    guard let data = data else {
                        reject(EndpointAuthorizerError.noDataPresent)
                        return
                    }

                    let dataString = String(data: data, encoding: String.Encoding.utf8)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        // TODO: Print dataString somewhere sensible
                        print("Invalid response object, data: \(dataString)")
                        reject(EndpointAuthorizerError.invalidHttpResponse(data: data))
                        return
                    }

                    guard 200..<300 ~= httpResponse.statusCode else {
                        // TODO: Print dataString somewhere sensible
                        print("Bad status code, data: \(dataString)")
                        reject(EndpointAuthorizerError.badResponseStatusCode(response: httpResponse, data: data))
                        return
                    }

                    guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []), let json = jsonObject as? [String: String] else {
                        // TODO: Log what was trying to be deserialzied here or in catch block where this is called
                        reject(EndpointAuthorizerError.unableToDeserializeJsonResponse)
                        return
                    }

                    guard json["jwt"] != nil else {
                        reject(EndpointAuthorizerError.jwtKeyNotPresentInResponse)
                        return
                    }

                    self.jwt = json["jwt"]!
                    fulfill(json["jwt"]!)
                })
            }
        }
    }
}

public enum EndpointAuthorizerError: Error {
    case unableToDeserializeJsonResponse
    case badResponseStatusCode(response: HTTPURLResponse, data: Data)
    case invalidHttpResponse(data: Data)
    case noDataPresent
    case jwtKeyNotPresentInResponse
}
