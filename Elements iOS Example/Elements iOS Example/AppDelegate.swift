//
//  AppDelegate.swift
//  Elements iOS Example
//
//  Created by Hamilton Chapman on 27/10/2016.
//  Copyright © 2016 Pusher. All rights reserved.
//

import UIKit
import ElementsSwift

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    public var elements: App!

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        let authorizer = SimpleTokenAuthorizer(jwt: "some.relevant.jwt")
        elements = try! App(id: "yourAppId", authorizer: authorizer)
        return true
    }
}

