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

    //poor man's dependency injection.
    public var elements: ElementsApp!
    public var notificationsHelper: UserNotificationsHelper?

    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        let authorizer = SimpleTokenAuthorizer(jwt: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJncmFudHMiOnsiL2FwcHMvKi91c2VyLW1lc3NhZ2luZyI6WyIqIl19LCJpc3MiOiI2NGVjM2Q4Yy1hNzg1LTQzZDUtOThhNS1lNjE0NWJhMTM0ODAifQ.PZhBZ1FOC1Q4tyH7esY7GqTGgj8YAjGqVGkS17Q1VFk");
        
        elements = try! ElementsApp(appId: "3", cluster: "localhost", authorizer: authorizer, client: BaseClient(cluster: "localhost", port: 10443));
        notificationsHelper = elements.userNotifications(userId: "zan")
        
        NSApplication.shared().registerForRemoteNotifications(matching: [.alert, .sound])
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    func application(_ application: NSApplication, didReceiveRemoteNotification userInfo: [String : Any]) {
        print("did receive remote notification!!!!")
    }
    
    func application(_ application: NSApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        notificationsHelper?.register(deviceToken: deviceToken)
    }

}
