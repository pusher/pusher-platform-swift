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
        let authorizer = HTTPEndpointAuthorizer(url: "https://your-endpoint.com/auth") { authRequest in
            // these are all optional and just examples of what you can do
            authRequest.body = ["something": "you want"]
            authRequest.headers = ["SomeHeader": "HeaderValue"]
            authRequest.queryItems = [URLQueryItem(name: "querykey", value: "some_value")]
            return authRequest
        }

        app = App(id: "your-app-id", authorizer: authorizer)

        return true
    }
}
