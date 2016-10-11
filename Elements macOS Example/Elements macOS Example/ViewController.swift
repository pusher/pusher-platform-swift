//
//  ViewController.swift
//  Elements macOS Example
//
//  Created by Hamilton Chapman on 27/09/2016.
//  Copyright © 2016 Pusher. All rights reserved.
//

import Cocoa
import ElementsSwift

class ViewController: NSViewController {
    var elements: ElementsApp!

    override func viewDidLoad() {
        super.viewDidLoad()

        let authorizer = ApiKey(appId: "2", key: "f47927a9-cffe-458e-b34b-ff6847444bda", secret: "66eUk3XGJmJDduzSMv58JA", grants: nil)
        elements = try! ElementsApp(appId: "2", jwt: nil, cluster: "https.beta.buildelements.com", authorizer: authorizer)

        let sub = elements.subscribe(path: "/lists/testlist")

        sub.onEvent = { data in
            let dataString = String(data: data, encoding: .utf8)
            print("Received this: \(dataString!)")
        }

        sleep(2)

        let promise = elements.request(method: "POST", path: "lists/testlist", jwt: nil, headers: nil, body: "testing from swift".data(using: .utf8))

        let promiseRes = promise.then { body in
            print("PROMISE RESOLVED and here is the body: \(String(data: body, encoding: .utf8)!)")
        }.catch { error in
            print("****************************************************************")
            print(error)
        }

        print(promiseRes)
    }

    override var representedObject: Any? {
        didSet {}
    }

}
