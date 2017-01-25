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
    public var pusher: App!

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

        let authorizer = SimpleTokenAuthorizer(jwt: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiI0ZmYwMjg1My1iZmVkLTQ1OTAtODBjNy00MGMwOWYyNWQxMTMiLCJpc3MiOiI4MDc4YjY5MS02ZWJjLTQ0YWEtOTUwMS1jYWIyOWVhZGMyZjUiLCJncmFudHMiOnsiL2FwcHMvNGZmMDI4NTMtYmZlZC00NTkwLTgwYzctNDBjMDlmMjVkMTEzLyoqIjpbIioiXX0sImlhdCI6MTQ4MDkzNjU5Mn0.Bq72BuPwqhxNFN9AEU-nvknGVUdeNIZ-d_je5k_R-m4")
        pusher = try! App(id: "4ff02853-bfed-4590-80c7-40c09f25d113", authorizer: authorizer)
        return true
    }
}

