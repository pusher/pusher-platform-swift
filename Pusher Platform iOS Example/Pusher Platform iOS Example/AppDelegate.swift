 //
//  AppDelegate.swift
//  Pusher Platform iOS Example
//
//  Created by Hamilton Chapman on 27/10/2016.
//  Copyright © 2016 Pusher. All rights reserved.
//

import UIKit
import PusherPlatform

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    public var app: App!

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

        app = try! App(id: "4ff02853-bfed-4590-80c7-40c09f25d113")
        return true
    }
}

