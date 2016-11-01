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
    let dispatchQueue: DispatchQueue = DispatchQueue(label: "elements-test")

    override func viewDidLoad() {
        super.viewDidLoad()

        let authorizer = SecretAuthorizer(appId: "2", secret: "f47927a9-cffe-458e-b34b-ff6847444bda:66eUk3XGJmJDduzSMv58JA", grants: nil)
        // elements = try! ElementsApp(appId: "2", cluster: "beta.buildelements.com", authorizer: authorizer)

        elements = try! ElementsApp(appId: "2", cluster: "localhost", authorizer: authorizer, client: BaseClient(cluster: "localhost", port: 10443))

        try! elements.subscribe(path: "/lists/testlist").then { sub in
            sub.onEvent = { data in
                let dataString = String(data: data, encoding: .utf8)
                print("Received this: \(dataString!)")
            }
        }

        print("After")
    }

    override var representedObject: Any? {
        didSet {}
    }

}



////
////  ViewController.swift
////  Elements macOS Example
////
////  Created by Hamilton Chapman on 27/09/2016.
////  Copyright © 2016 Pusher. All rights reserved.
////
//
//import Cocoa
//import ElementsSwift
//import PromiseKit
//
//class ViewController: NSViewController {
//    var elements: ElementsApp!
//    let dispatchQueue: DispatchQueue = DispatchQueue(label: "elements-test")
//
//    override func viewDidLoad() {
//        super.viewDidLoad()
//
//        let authorizer = SecretAuthorizer(appId: "2", secret: "f47927a9-cffe-458e-b34b-ff6847444bda:66eUk3XGJmJDduzSMv58JA", grants: nil)
//        elements = try! ElementsApp(appId: "2", cluster: "beta.buildelements.com", authorizer: authorizer)
//
//        try! elements.sub(path: "/lists/testlist").then { sub in
//            sub.onEvent = { data in
//                let dataString = String(data: data, encoding: .utf8)
//                print("Received this: \(dataString!)")
//            }
//            }.catch { error in
//                print("Error: \(error)")
//        }
//
//        print("After")
//    }
//
//    override var representedObject: Any? {
//        didSet {}
//    }
//
//}
//
//
//
////.then { () -> Promise<Data> in
////    print("Gonna make the second request")
////    sleep(2)
////    return self.elements.request(method: "APPEND", path: "lists/testlist", jwt: nil, headers: nil, body: "testing from swift".data(using: .utf8))
////    }.then { body in
////        print("PROMISE RESOLVED and here is the body: \(String(data: body, encoding: .utf8)!)")
////}

