public class UserNotificationsHelper: NSObject, ServiceHelper {
    public var app: ElementsApp
    static public let namespace = "user-notifications"
    public var notificationName: String
    
    public init(app: ElementsApp, notificationName: String){
        self.app = app
        self.notificationName = notificationName
        
        print("Hello UserNotifications, my name is \(notificationName)")
    }
    
    var sub: Subscription?
    
    /**
        Subscribe to in-app User Notifications
        
        - parameter notificationHandler:    A function that will be called for each notification that is sent to this user.
        - parameter receiptHandler: A function that will be called for each receipt that is sent to this user.
     */
    public func subscribe(
        notificationHandler: @escaping (String, Any) -> (),
        receiptHandler: @escaping (String) -> ()){
        
        try! self.app.subscribe(path: "user-notifications/users/" + self.notificationName + "/notifications").then { sub -> () in
            self.sub = sub
            sub.onEvent = { (eventId, headers, body) in
                print("Received this: \(eventId), \(headers), \(body)");
                let bodyDict = body as! [String: Any];
                let eventType : String = bodyDict["type"] as! String;
                switch eventType {
                case "notification":
                    let notificationId : String = bodyDict["notificationId"] as! String;
                    let body : Any = bodyDict["body"];
                    notificationHandler(notificationId, body);
                    break;
                case "receipt":
                    let notificationId : String = bodyDict["notificationId"] as! String;
                    receiptHandler(notificationId);
                default:
                    break;
                }
            }
            //TODO: ask Ham about this
//            sub.onEnd = {
//                ((somethingIng, [someString: someString], somethingCompletelyDifferent) in
//            }
        }
    }
    

    //TODO: this might be a very java thing to do :P
    /**
        Check whether there's a subscription currently active
        
        - returns: true if there is an open subscription currently, false otherwise
     */
    public func isSubscribed() -> Bool {
        return sub != nil
    }
    
    //TODO: is this sensible?
    /**
        Cancel the current subscription.
     
        - returns: true if the subscription was canceled, false otherwise
     */
    public func unsubscribe() -> Bool {
        
        let subscribedTaskIdentifier = sub?.taskIdentifier
        var taskUnsubscribed = false
        
        app.client.subscriptionUrlSession.getAllTasks(completionHandler: { (tasks) in
            
            for task in tasks {
                if task.taskIdentifier == subscribedTaskIdentifier {
                    task.suspend()
                    taskUnsubscribed = true
                    self.sub = nil
                    break
                }
            }
        })
        return taskUnsubscribed
    }
    
    /**
        Acknowledge the receipt of a notification
        
        - parameter notificationId: notificationId of a notification passed to the notificationHandler when subscribing
     */
    public func acknowledge(notificationId: String) {
        guard let bodyJson = try!JSONSerialization.data(withJSONObject: ["type": "receipt", "notificationId": notificationId], options: []) as? Data else {
            //TODO: throw exception
            print("Failed creating JSON body for sending acknowledge")
        }
        let _ = self.app.request(method: "POST", path: "user-notifications/users/" + self.notificationName + "/receipts", jwt: nil, headers: nil, body: bodyJson);
    }
    
    /**
        Registers the device token in order to receive push notifications
     
        - parameter deviceToken:    the token we in the AppDelegate after successfully registering for push notifications: `didRegisterForRemoteNotificationsWithDeviceToken`
     */
    public func register(deviceToken: Data){
        
        var token: String = "";
        for i in 0..<deviceToken.count {
            token += String(format: "%02.2hhx", deviceToken[i] as CVarArg);
        }

        
        guard let bodyJson = try!JSONSerialization.data(withJSONObject: ["deviceToken": token], options: []) as? Data else {
            //TODO: throw exception
            print("Failed creating JSON body for registration with device token")
        }
        
        let _ = self.app.request(method: "POST", path: "user-notifications/users/\(self.notificationName)/devices/apns", jwt: nil, headers: nil, body: bodyJson)
    }
    
    /**
        Unregisters the device token from receiving push notifications
     
        - parameter deviceToken: the same token we registered with in the AppDelegate
     */
    public func unregister(deviceToken: Data){
        guard let bodyJson = try!JSONSerialization.data(withJSONObject: ["deviceToken": deviceToken], options: []) as? Data else {
            //TODO: throw exception
            print("Failed creating JSON body for unregistering device token")
        }
        let _ = self.app.request(method: "DELETE", path: "user-notifications/users/deviceTokens", jwt: nil, headers: nil, body: bodyJson)
    }
}
