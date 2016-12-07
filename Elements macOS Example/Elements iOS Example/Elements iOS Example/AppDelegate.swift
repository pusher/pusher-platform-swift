//
//  AppDelegate.swift
//  Elements iOS Example
//
//  Created by Hamilton Chapman on 27/10/2016.
//  Copyright © 2016 Pusher. All rights reserved.
//

import UIKit
import ElementsSwift
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    public var elements: App!
    public var notificationsHelper: UserNotificationsHelper?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        let authorizer = SimpleTokenAuthorizer(jwt: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJncmFudHMiOnsiL2FwcHMvKi91c2VyLW5vdGlmaWNhdGlvbnMvKioiOlsiKiJdfSwiaXNzIjoiNjRlYzNkOGMtYTc4NS00M2Q1LTk4YTUtZTYxNDViYTEzNDgwIn0.QkPB2acA9HrkFytmcXxeSbyPXyoAz2-OmSTQ7lBQCn4")
        elements = try! App(id: "3", authorizer: authorizer)
        notificationsHelper = elements.userNotifications(userId: "zan")
        
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options:[.badge, .alert, .sound]) { (granted, error) in
            guard granted else {
                return
            }
            application.registerForRemoteNotifications()
        }
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        
        try! notificationsHelper?.register(deviceToken: deviceToken)
    }
}

