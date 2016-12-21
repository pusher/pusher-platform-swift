import Foundation

@objc public class SubscriptionDelegate: NSObject {

}




@objc public class SubscriptionManager: NSObject {
    // TODO: Remove me
//    public var subscriptions: [Int: (subscription: Subscription, resolvers: Resolvers)] = [:]

    // TODO: If we use [Int] then we need to be very careful to avoid conflicts in taskIds (i.e. always ensure cleanup is finished before adding a new taskId)
    public var subscriptions: [Int: Subscription] = [:]

    internal func handle(taskIdentifier: Int, response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        defer {
            completionHandler(.allow)
        }

        guard subscriptions.contains(taskIdentifier) else {
            return
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            return
        }

        if 200..<300 ~= httpResponse.statusCode {

            // TODO: THIS IS THE IMPORTANT BIT FOR STRUCTURAL CONSIDERATIONS - WHAT OWNS / REFERENCES WHAT?


            // TODO: when do we call onOpen on the subscription? do we need to if we're using promises?
            // if we were to call it, it would be here, after fulfilling the subscription, I suppose
//            subTuple.resolvers.promiseFulfiller(subTuple.subscription)
            print("We good")
        } else {
//            subTuple.resolvers.promiseRejector(RequestError.invalidHttpResponse(data: nil))
            print("We bad")
        }
    }

    internal func handle(messages: [Message], taskIdentifier: Int) {
        guard let sub = self.subscriptions[taskIdentifier]?.subscription else {
            print("No subscription found paired with taskIdentifier \(taskIdentifier)")
            return
        }

        for message in messages {
            switch message {
            case Message.keepAlive:
                break
            case Message.event(let eventId, let headers, let body):
                sub.onEvent?(eventId, headers, body)
            case Message.eos(let statusCode, let headers, let info):
                sub.onEnd?(statusCode, headers, info)
            }
        }
    }

    internal func handleError(taskIdentifier: Int, error: Error?) {
        guard let subTuple = subscriptions[taskIdentifier] else {
            return
        }

        // TODO: do we want to call the promiseRejector for the sub here?
        // TODO: Test having a sub succeed and then fail and see what happens with
        // a catch if you then reject the promise having already resolved it

        // TODO: Do we want localizedDescription or just the error?
        subTuple.subscription.onEnd?(nil, nil, error)
    }
}

// TODO: Remove me
//@objc public class Resolvers: NSObject {
//    public let promiseFulfiller: (Subscription) -> Void
//    public let promiseRejector: (Error) -> Void
//
//    public init(promiseFulfiller: @escaping (Subscription) -> Void, promiseRejector: @escaping (Error) -> Void) {
//        self.promiseFulfiller = promiseFulfiller
//        self.promiseRejector = promiseRejector
//    }
//}
