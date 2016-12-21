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
    var elements: App!

    override func viewDidLoad() {
        let authorizer = SimpleTokenAuthorizer(jwt: "some.relevant.jwt")
        
        elements = try! App(id: "yourAppId", authorizer: authorizer)

        let resumable = elements.feeds("resumable-ham")

        resumable.subscribeWithResume(
            onOpen: { Void in print("OPEN") },
            onAppend: { itemId, headers, item in print("RECEIVED: ", itemId, headers, item) } ,
            onEnd: { statusCode, headers, info in print("END: ", statusCode, headers, info) },
            onError: { error in print("ERROR: ", error) },
            onStateChange: { oldState, newState in print("was \(oldState) now \(newState)") }
        ) { result in
                print("RESULT: ", result)
        }

//        resumable.get(limit: 10) { result in
//            print("Got a result, and here it is: \(result)")
//            print(result.value?.items)
//            print(result.value?.nextId)
//        }
//
//        resumable.append(item: "testing") { result in
//            print("Got a result, and here it is: \(result)")
//            print(result.value)
//        }

    }

    override var representedObject: Any? {
        didSet {}
    }
}
