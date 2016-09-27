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
    var elements: ElementsClient!

    override func viewDidLoad() {
        super.viewDidLoad()

        let elementsConfig = ElementsClientConfig(token: "some.random.token.", host: "localhost", namespace: .appId("123"), port: 10443)
        elements = ElementsClient(config: elementsConfig)

        elements.subscribe(path: "/list/testlist")
    }

    override var representedObject: Any? {
        didSet {}
    }

}
