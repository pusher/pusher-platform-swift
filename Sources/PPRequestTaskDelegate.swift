import Foundation

public protocol PPRequestTaskDelegate {
    var task: URLSessionTask? { get set }
    var logger: PPLogger? { get set }

    init()

    // TODO: Is this necessary or will we always receive data on error?
//    var waitForDataAccompanyingBadStatusCodeResponseTimer: Timer? { get set }
}


public enum PPRequestTaskDelegateError: Error {
    case invalidHTTPResponse(response: URLResponse)
    case badResponseStatusCode(response: HTTPURLResponse)
    case badResponseStatusCodeWithMessage(response: HTTPURLResponse, errorMessage: String)
}

extension PPRequestTaskDelegateError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidHTTPResponse(let response):
            return "Invalid HTTP response received: \(response.debugDescription)"
        case .badResponseStatusCode(let response):
            return "Bad response status code received: \(response.statusCode)"
        case .badResponseStatusCodeWithMessage(let response, let errorMessage):
            return "Bad response status code received: \(response.statusCode) with error message: \(errorMessage)"
        }
    }
}
