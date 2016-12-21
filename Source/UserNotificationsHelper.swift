//public class UserNotificationsHelper: NSObject, ServiceHelper {
//    static public let namespace = "user-notifications"
//
//    public var app: App? = nil
//    public var notificationName: String
//
//    public init(notificationName: String, app: App){
//        self.notificationName = notificationName
//        self.app = app
//    }
//
//    public var subscriptionTaskId: Int? = nil
//
//    // TODO: We should probably be returning the underlying subscription, or some sort of wrapper
//    // TODO: Should we be giving users the option of using a ResumableSubscription, as in FeedsHelper?
//    /**
//        Subscribe to in-app User Notifications
//
//        - parameter notificationHandler: A function that will be called for each notification that
//                                         is sent to this user
//        - parameter receiptHandler:      A function that will be called for each receipt that is
//                                         sent to this user
//     */
//    public func subscribe(notificationHandler: @escaping (String, Any) -> Void, receiptHandler: @escaping (String) -> Void) throws {
//        guard self.app != nil else {
//            throw ServiceHelperError.noAppObject
//        }
//
//        let path = "/\(UserNotificationsHelper.namespace)/users/\(self.notificationName)/notifications"
//
//        try! self.app!.subscribe(path: path).then { sub -> Void in
//            self.subscriptionTaskId = sub.taskIdentifier
//
//            // TODO: Not sure we should be setting the onEvent on the sub directly in the subscribe call,
//            // without returning it
//            // TODO: We should do something about throwing suitable errors or calling error handlers (or
//            // something equivalent)
//            // TODO: What are we doing with onEnd, onOpen on the subscription?
//            sub.onEvent = { (eventId, headers, body) in
//                guard let bodyDict = body as? [String: Any] else {
//                    print("Body couldn't be cast to a dictionary")
//                    return
//                }
//
//                guard let eventType = bodyDict["type"] as? String else {
//                    print("Body dictionary doesn't contain a valid type")
//                    return
//                }
//
//                switch eventType {
//                case "notification":
//                    guard let notificationId = bodyDict["notificationId"] as? String, let notificationBody = bodyDict["body"] else {
//                        print("Invalid notification received: \(bodyDict)")
//                        return
//                    }
//
//                    notificationHandler(notificationId, notificationBody)
//                case "receipt":
//                    guard let notificationId = bodyDict["notificationId"] as? String else {
//                        print("Invalid receipt received: \(bodyDict)")
//                        return
//                    }
//
//                    receiptHandler(notificationId)
//                default:
//                    print("Unexpected type received: \(eventType)")
//                    break
//                }
//            }
//        }
//    }
//
//    /**
//        Check whether there's a subscription currently active
//
//        - returns: true if there is an open subscription currently, false otherwise
//     */
//    public func isSubscribed() -> Bool {
//        return self.subscriptionTaskId != nil
//    }
//
//    //TODO: should we return a Bool denoting whether or not the unsubscribe was successful
//    //TODO: the guard check is repeated in every method call - is there anything we could do about that?
//    /**
//        Cancel the current subscription.
//
//        - returns: true if the subscription was canceled, false otherwise
//     */
//    public func unsubscribe() throws {
//        guard self.app != nil else {
//            throw ServiceHelperError.noAppObject
//        }
//
//        guard self.subscriptionTaskId != nil else {
//            throw UserNotificationsHelperError.noSubscriptionTaskIdentifier
//        }
//
//        self.app!.unsubscribe(taskIdentifier: subscriptionTaskId!)
//        self.subscriptionTaskId = nil
//    }
//
//    /**
//        Acknowledge the receipt of a notification
//
//        - parameter notificationId: notificationId of a notification passed to the notificationHandler
//                                    when subscribing
//     */
//    public func acknowledge(notificationId: String) throws {
//        guard self.app != nil else {
//            throw ServiceHelperError.noAppObject
//        }
//
//        let ackBody = ["type": "receipt", "notificationId": notificationId]
//
//        guard let bodyJson = try? JSONSerialization.data(withJSONObject: ackBody, options: []) else {
//            throw UserNotificationsHelperError.failedToJSONSerializeAcknowledgementBody(ackBody)
//        }
//
//        let path = "/\(UserNotificationsHelper.namespace)/users/\(self.notificationName)/receipts"
//
//        self.app!.request(method: "POST", path: path, body: bodyJson)
//    }
//
//    /**
//        Registers the device token in order to receive push notifications
//
//        - parameter deviceToken: the token we get in the AppDelegate after successfully registering
//                                 for push notifications
//     */
//    public func register(deviceToken: Data) throws {
//        guard self.app != nil else {
//            throw ServiceHelperError.noAppObject
//        }
//
//        let token = stringifyDeviceToken(data: deviceToken)
//
//        guard let bodyJson = try? JSONSerialization.data(withJSONObject: ["deviceToken": token], options: []) else {
//            throw UserNotificationsHelperError.failedToJSONSerializeDeviceToken(token)
//        }
//
//        let path = "/\(UserNotificationsHelper.namespace)/users/\(self.notificationName)/devices/apns"
//
//        self.app!.request(method: "POST", path: path, body: bodyJson)
//    }
//
//    /**
//        Unregisters the device token from receiving push notifications
//
//        - parameter deviceToken: the same token we registered with in the AppDelegate
//     */
//    public func unregister(deviceToken: Data) throws {
//        guard self.app != nil else {
//            throw ServiceHelperError.noAppObject
//        }
//
//        let token = stringifyDeviceToken(data: deviceToken)
//
//        guard let bodyJson = try? JSONSerialization.data(withJSONObject: ["deviceToken": token], options: []) else {
//            throw UserNotificationsHelperError.failedToJSONSerializeDeviceToken(token)
//        }
//
//        let path = "/\(UserNotificationsHelper.namespace)/users/\(self.notificationName)/deviceTokens"
//
//        self.app!.request(method: "DELETE", path: path, body: bodyJson)
//    }
//
//    internal func stringifyDeviceToken(data: Data) -> String {
//        var token: String = ""
//
//        for i in 0..<data.count {
//            token += String(format: "%02.2hhx", data[i] as CVarArg)
//        }
//
//        return token
//    }
//}
//
//public enum UserNotificationsHelperError: Error {
//    case failedToJSONSerializeDeviceToken(String)
//    case failedToJSONSerializeAcknowledgementBody([String: String])
//    case noSubscriptionTaskIdentifier
//}
