////
////  SubscriptionManager.swift
////  ElementsSwift
////
////  Created by Hamilton Chapman on 26/10/2016.
////
////

import Foundation
import PromiseKit

@objc public class SubscriptionManager: NSObject {
    public var subscriptions: [Int: (subscription: Subscription, resolvers: Resolvers)] = [:]

    // TODO: Decide what to do with init
//     public init() {}

    internal func handle(taskIdentifier: Int, response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        defer {
            completionHandler(.allow)
        }

        guard let subTuple = subscriptions[taskIdentifier] else {
            return
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            return
        }

        if 200..<300 ~= httpResponse.statusCode {
            // TODO: when do we call onOpen on the subscription? do we need to if we're using promises?
            // if we were to call it, it would be here, after fulfilling the subscription, I suppose
            subTuple.resolvers.promiseFulfiller(subTuple.subscription)
        } else {
            subTuple.resolvers.promiseRejector(RequestError.invalidHttpResponse(data: nil))
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

@objc public class Resolvers: NSObject {
    public let promiseFulfiller: (Subscription) -> Void
    public let promiseRejector: (Error) -> Void

    public init(promiseFulfiller: @escaping (Subscription) -> Void, promiseRejector: @escaping (Error) -> Void) {
        self.promiseFulfiller = promiseFulfiller
        self.promiseRejector = promiseRejector
    }
}
