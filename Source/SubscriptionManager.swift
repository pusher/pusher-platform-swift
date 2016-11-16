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

    internal func handle(task: URLSessionDataTask, response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        defer {
            completionHandler(.allow)
        }

        guard let subTuple = subscriptions[task.taskIdentifier] else {
            return
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            return
        }

        if 200..<300 ~= httpResponse.statusCode {
            subTuple.resolvers.promiseFulfiller(subTuple.subscription)
        } else {
            subTuple.resolvers.promiseRejector(RequestError.invalidHttpResponse(data: nil))
        }
    }

    internal func handle(message: Message, taskIdentifier: Int) {
        guard let sub = self.subscriptions[taskIdentifier]?.subscription else {
            print("No subscription found paired with taskIdentifier \(taskIdentifier)")
            return
        }

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

@objc public class Resolvers: NSObject {
    public let promiseFulfiller: (Subscription) -> Void
    public let promiseRejector: (Error) -> Void

    public init(promiseFulfiller: @escaping (Subscription) -> Void, promiseRejector: @escaping (Error) -> Void) {
        self.promiseFulfiller = promiseFulfiller
        self.promiseRejector = promiseRejector
    }
}
