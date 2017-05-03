import Foundation

internal protocol PPRequestTaskDelegate {
    var data: Data { get set }
    var task: URLSessionDataTask? { get set }
    var error: Error? { get set }
    var logger: PPLogger? { get set }

    // If there's a bad response status code then we need to wait for
    // data to be received before communicating the error to the handler
    var badResponse: HTTPURLResponse? { get set }

    var waitForDataAccompanyingBadStatusCodeResponseTimer: Timer? { get set }

    init(task: URLSessionDataTask?)

    func handle(_ response: URLResponse, completionHandler: (URLSession.ResponseDisposition) -> Void)
    func handle(_ data: Data)
    func handleCompletion(error: Error?)
}
