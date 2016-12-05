public class UserNotificationsHelper: NSObject, ServiceHelper {
    static public let namespace = "user-notifications"

    public var app: ElementsApp? = nil
    public var notificationName: String
    
    public init(notificationName: String, app: ElementsApp){
        self.notificationName = notificationName
        self.app = app
    }
    
    public var subscriptionTaskId: Int? = nil
    
    /**
        Subscribe to in-app User Notifications
        
        - parameter notificationHandler: A function that will be called for each notification that 
                                         is sent to this user
        - parameter receiptHandler:      A function that will be called for each receipt that is 
                                         sent to this user
     */
    public func subscribe(notificationHandler: @escaping (String, Any) -> Void, receiptHandler: @escaping (String) -> Void) throws {
        guard self.app != nil else {
            throw ServiceHelperError.noAppObject
        }

        let path = "/\(UserNotificationsHelper.namespace)/users/\(self.notificationName)/notifications"

        try! self.app!.subscribe(path: path).then { sub -> Void in
            self.subscriptionTaskId = sub.taskIdentifier

            sub.onEvent = { (eventId, headers, body) in


                let bodyDict = body as! [String: Any]
                let eventType: String = bodyDict["type"] as! String
                switch eventType {
                case "notification":
                    let notificationId : String = bodyDict["notificationId"] as! String
                    let body : Any = bodyDict["body"]
                    notificationHandler(notificationId, body)
                case "receipt":
                    let notificationId : String = bodyDict["notificationId"] as! String
                    receiptHandler(notificationId)
                default:
                    print("Unexpected type received: \(eventType)")
                    break
                }
            }
        }
    }

    //TODO: this might be a very java thing to do :P
    /**
        Check whether there's a subscription currently active
        
        - returns: true if there is an open subscription currently, false otherwise
     */
    public func isSubscribed() -> Bool {
        return self.subscriptionTaskId != nil
    }
    
    //TODO: should we return a Bool denoting whether or not the unsubscribe was successful
    /**
        Cancel the current subscription.
     
        - returns: true if the subscription was canceled, false otherwise
     */
    public func unsubscribe() throws {
        guard self.app != nil else {
            throw ServiceHelperError.noAppObject
        }

        guard self.subscriptionTaskId != nil else {
            throw UserNotificationsHelperError.noSubscriptionTaskIdentifier
        }

        self.app!.unsubscribe(taskIdentifier: subscriptionTaskId!)
    }
    
    /**
        Acknowledge the receipt of a notification
        
        - parameter notificationId: notificationId of a notification passed to the notificationHandler 
                                    when subscribing
     */
    public func acknowledge(notificationId: String) throws {
        guard self.app != nil else {
            throw ServiceHelperError.noAppObject
        }

        let ackBody = ["type": "receipt", "notificationId": notificationId]

        guard let bodyJson = try JSONSerialization.data(withJSONObject: ackBody, options: []) as? Data else {
            throw UserNotificationsHelperError.failedToJSONSerializeAcknowledgementBody(ackBody)
        }

        let path = "/\(UserNotificationsHelper.namespace)/users/\(self.notificationName)/receipts"

        self.app!.request(method: "POST", path: path, body: bodyJson)
    }
    
    /**
        Registers the device token in order to receive push notifications
     
        - parameter deviceToken: the token we get in the AppDelegate after successfully registering 
                                 for push notifications
     */
    public func register(deviceToken: Data) throws {
        guard self.app != nil else {
            throw ServiceHelperError.noAppObject
        }
        
        let token = stringifyDeviceToken(data: deviceToken)

        guard let bodyJson = try JSONSerialization.data(withJSONObject: ["deviceToken": token], options: []) as? Data else {
            throw UserNotificationsHelperError.failedToJSONSerializeDeviceToken(token)
        }

        let path = "/\(UserNotificationsHelper.namespace)/users/\(self.notificationName)/devices/apns"

        self.app!.request(method: "POST", path: path, body: bodyJson)
    }
    
    /**
        Unregisters the device token from receiving push notifications
     
        - parameter deviceToken: the same token we registered with in the AppDelegate
     */
    public func unregister(deviceToken: Data) throws {
        guard self.app != nil else {
            throw ServiceHelperError.noAppObject
        }

        let token = stringifyDeviceToken(data: deviceToken)

        guard let bodyJson = try JSONSerialization.data(withJSONObject: ["deviceToken": token], options: []) as? Data else {
            throw UserNotificationsHelperError.failedToJSONSerializeDeviceToken(token)
        }

        let path = "/\(UserNotificationsHelper.namespace)/users/\(self.notificationName)/deviceTokens"

        self.app!.request(method: "DELETE", path: path, body: bodyJson)
    }

    internal func stringifyDeviceToken(data: Data) -> String {
        var token: String = ""

        for i in 0..<data.count {
            token += String(format: "%02.2hhx", data[i] as CVarArg)
        }

        return token
    }
}

public enum UserNotificationsHelperError: Error {
    case failedToJSONSerializeDeviceToken(String)
    case failedToJSONSerializeAcknowledgementBody([String: String])
    case noSubscriptionTaskIdentifier
}
