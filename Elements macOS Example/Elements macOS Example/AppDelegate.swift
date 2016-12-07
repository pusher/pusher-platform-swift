//
//  AppDelegate.swift
//  Elements macOS Example
//
//  Created by Hamilton Chapman on 27/09/2016.
//  Copyright © 2016 Pusher. All rights reserved.
//

import Cocoa
import ElementsSwift

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    public var elements: App!
    public var notificationsHelper: UserNotificationsHelper?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        let authorizer = SimpleTokenAuthorizer(jwt: "YOUR.CLIENT.JWT")
        elements = try! App(id: "3", authorizer: authorizer)

        notificationsHelper = elements.userNotifications(userId: "zan")
        
        NSApplication.shared().registerForRemoteNotifications(matching: [.alert, .sound])
    }

    func applicationWillTerminate(_ aNotification: Notification) {}
    
    func application(_ application: NSApplication, didReceiveRemoteNotification userInfo: [String : Any]) {
        print("Received remote notification: \(userInfo)")
    }
    
    func application(_ application: NSApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        try! notificationsHelper?.register(deviceToken: deviceToken)
    }

}
