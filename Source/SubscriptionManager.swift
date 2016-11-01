//
//  BaseClientConnectionManager.swift
//  ElementsSwift
//
//  Created by Hamilton Chapman on 26/10/2016.
//
//

import Foundation

// TODO: not sure if this is the best abstaction - do we even want a separate "manager" object?
@objc public class ConnectionManager: NSObject {
    public var subscriptions: [Int: Subscription] = [:]

    // public init() {}
}



////
////  SubscriptionManager.swift
////  ElementsSwift
////
////  Created by Hamilton Chapman on 26/10/2016.
////
////
//
//import Foundation
//import PromiseKit
//
//
//// TODO: THINK ABOUT ALL OF THIS - IT FEELS MAD
//
//
//// TODO: not sure if this is the best abstaction - do we even want a separate "manager" object?
//@objc public class SubscriptionManager: NSObject {
//    public var subscriptions: [Int: (subscription: Subscription, resolvers: Resolvers)] = [:]
//
//    // public init() {}
//
//    public func handle(task: URLSessionDataTask, response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
//        print("Hey i'm handling")
//
//        defer {
//            print("I'm in the defer")
//            completionHandler(.allow)
//        }
//
//        guard let subTuple = subscriptions[task.taskIdentifier] else {
//            print("No sub tuple")
//            return
//        }
//
//        guard let httpResponse = response as? HTTPURLResponse else {
//            print("Not a response")
//            return
//        }
//
//        if 200..<300 ~= httpResponse.statusCode {
//            print("Fulfill that fucker")
//            subTuple.resolvers.promiseFulfiller(subTuple.subscription)
//        } else {
//            print("REJECT that fucker")
//            subTuple.resolvers.promiseRejector(RequestError.invalidHttpResponse)
//        }
//    }
//}
//
//@objc public class Resolvers: NSObject {
//    public let promiseFulfiller: (Subscription) -> Void
//    public let promiseRejector: (Error) -> Void
//
//    public init(promiseFulfiller: @escaping (Subscription) -> Void, promiseRejector: @escaping (Error) -> Void) {
//        self.promiseFulfiller = promiseFulfiller
//        self.promiseRejector = promiseRejector
//    }
//}
//
//
//
//
//
