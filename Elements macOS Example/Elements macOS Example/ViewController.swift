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

class ClickHandler {
    var handler: () -> ()

    init(handler: @escaping () -> ()) {
        self.handler = handler
    }

    @objc public func buttonClick() {
        self.handler()
    }
}

class ViewController: NSViewController {
    var elements: ElementsApp!
    var handlers: [ClickHandler] = []
    var delegate: AppDelegate!
    
    @IBOutlet weak var stackView: NSStackView!
    @IBOutlet weak var topLabel: NSTextField!
    
    @IBAction func subscribeButton(_ sender: Any) { onSubscribe() }
    @IBAction func unsubscribeButton(_ sender: Any) { onUnsubscribe() }
    @IBAction func registerButton(_ sender: Any) { onRegister() }
    @IBAction func unregisterButton(_ sender: Any) { onUnRegister() }

    override func viewDidLoad() {
        delegate = NSApplication.shared().delegate as! AppDelegate

        let authorizer = try! SecretAuthorizer(appId: "2", secret: "secret:somekey:somesecret", grants: nil)
        elements = try! ElementsApp(appId: "2", cluster: "beta.buildelements.com", authorizer: authorizer)

        let resumable = elements.feeds(feedName: "resumable-newer")

        try! resumable.subscribeWithResume(
            onOpen: { Void in print("We're open") },
            onAppend: { itemId, headers, item in print("RECEIVED", itemId, headers, item) } ,
            onEnd: { statusCode, headers, info in print("END", statusCode, headers, info) },
            onStateChange: { oldState, newState in print("was \(oldState) now \(newState)") }).then { resSub -> Void in
                print("Subscribed!")
            }.then { Void in
                try! resumable.append(item: ["newValue": 777]).then { appendRes -> Void in
                    print(appendRes)
                }
            }.catch { error in
                print(error)
        }
    }
    
    func onSubscribe() {
        guard delegate.notificationsHelper?.isSubscribed() == false else {
            print("I am already subscribed!")
            return
        }

        try! delegate.notificationsHelper?.subscribe(
            notificationHandler: myNotificationHandler,
            receiptHandler: { (notificationId: String) -> () in
                print("I was informed that user notification was read: \(notificationId.debugDescription)")
        })

        print("Subscribed for in-app notifications!")

        topLabel.stringValue = "Subscribed to in-app notifications"
    }
    
    func onUnsubscribe() {
        guard delegate.notificationsHelper?.isSubscribed() == true else {
            print("I am not subscribed. Go away")
            return
        }
        
        try! delegate.notificationsHelper?.unsubscribe()

        print("Unsubscribing from in-app notifications")

        topLabel.stringValue = "Unsubscribed from in-app notifications"
    }
    
    func myNotificationHandler(notificationId: String, body: Any) {
        
        let sv = NSStackView(frame: NSRect(x: 100, y: 100, width: 100, height: 100))
        sv.userInterfaceLayoutDirection = NSUserInterfaceLayoutDirection.leftToRight
        
        let newLabel = NSTextField(frame: NSRect(x: 100, y: 100, width: 100, height: 100))
        newLabel.isEditable = false
        newLabel.stringValue = "\(notificationId.debugDescription): \(body)"
        
        sv.addView(newLabel, in: NSStackViewGravity.leading)
        
        let button = NSButton(frame: NSRect(x: 100, y: 100, width: 100, height: 100))
        
        let handler = ClickHandler(handler: {
            try! self.delegate.notificationsHelper?.acknowledge(notificationId: notificationId)

            button.title = "Acknowledged!"
        })

        self.handlers.append(handler)  // DISGRACE: keep strong reference
        
        button.title = "Acknowledge"
        button.target = handler  // DISGRACE: button.target is a weak reference
        button.action = #selector(handler.buttonClick)
        
        
        sv.addView(button, in: NSStackViewGravity.leading)
        
        DispatchQueue.main.async {
            self.stackView.addView(sv, in: NSStackViewGravity.top)
        }
        
        print("Received user notification: \(notificationId.debugDescription)")
    }
    
    func onRegister() { print("onRegister") }
    func onUnRegister() { print("onUnregister") }

    override var representedObject: Any? {
        didSet {}
    }
}
