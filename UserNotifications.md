User Notifications
===

Requesting a UserNotifications object is done with a userId:


```swift

let app: ElementsApp = createElementsApp(/* here be dragons */)

let notifications = app.userNotifications(userId: "userId")

```

Subscriptions are passed a notification and receipt handler: 

```swift

let notificationHandler: @escaping (String, Any) -> ()
let receiptHandler: @escaping (String) - ()

notifications.subscribe(
    notificationHandler: notificationHandler,
    receiptHandler: receiptHandler)

```

Helper Functions for subscriptions to check, retrieve, cancel

```swift

notifications.isSubscribed() -> Bool
notifications.unsubscribe() -> Bool

```

Acknowledge receipt of a notification:

```swift

notifications.acknowledge(notificationId: "notificationId")

```

Registering a device token for APNS in AppDelegate

```swift

func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    
    register(deviceToken: "deviceToken")
}


```

Unregister from APNS


```swift

notifications.unregister(deviceToken: Data) -> Bool

```
