//
//  ViewController.swift
//  Elements macOS Example
//
//  Created by Hamilton Chapman on 27/09/2016.
//  Copyright © 2016 Pusher. All rights reserved.
//

import Cocoa
import ElementsSwift
import PromiseKit

class ViewController: NSViewController {
    var elements: ElementsApp!

    override func viewDidLoad() {
        super.viewDidLoad()

        let authorizer = try! SecretAuthorizer(appId: "2", secret: "secret:YOUR_KEY:YOUR_SECRET", grants: nil)
        elements = try! ElementsApp(appId: "2", cluster: "beta.buildelements.com", authorizer: authorizer)

        // localhost example
//        elements = try! ElementsApp(appId: "2", cluster: "localhost", authorizer: authorizer, client: BaseClient(cluster: "localhost", port: 10443))

        try! elements.subscribe(path: "/lists/testlist").then { sub -> () in
            print("1st promise resolved")
            sub.onEvent = { data in
                let dataString = String(data: data, encoding: .utf8)
                print("Received this: \(dataString!)")
            }
        }.then { () -> Promise<Data> in
            return self.elements.request(method: "APPEND", path: "lists/testlist", jwt: nil, headers: nil, body: "testing from swift".data(using: .utf8))
        }.then { body in
            print("Body in response to append: \(String(data: body, encoding: .utf8)!)")
        }
    }

    override var representedObject: Any? {
        didSet {}
    }

}
