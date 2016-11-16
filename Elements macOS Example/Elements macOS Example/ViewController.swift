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
    var handler : () -> ();

    init(handler: @escaping () -> ()) {
        self.handler = handler;
    }

    @objc public func buttonClick() {
        self.handler();
    }
}

class ViewController: NSViewController {
    
    @IBOutlet weak var stackView: NSStackView!
    
    @IBOutlet weak var topLabel: NSTextField!
    
    @IBAction func subscribeButton(_ sender: Any) {
        onSubscribe()
    }
    
    @IBAction func unsubscribeButton(_ sender: Any) {
        onUnsubscribe()
    }
    
    @IBAction func registerButton(_ sender: Any) {
        onRegister()
    }
    @IBAction func unregisterButton(_ sender: Any) {
        onUnRegister();
    }
    
//    var elementsApp: ElementsApp!

    var handlers: [ClickHandler] = []
    
//    var zanNotifications: UserNotificationsHelper?
    
    var delegate: AppDelegate!

    override func viewDidLoad() {
        super.viewDidLoad();
        delegate = NSApplication.shared().delegate as! AppDelegate
    }
    
    func onSubscribe(){
        guard delegate.notificationsHelper?.isSubscribed() == false else {
            print("I am already subscribed!")
            return
        }
        
        delegate.notificationsHelper?.subscribe(
            notificationHandler: myNotificationHandler,
            receiptHandler: { (notificationId: String) -> () in
                print("I was informed that user notification was read: \(notificationId.debugDescription)")
        })
        print("Subscribed for in-app notifications!")
        topLabel.stringValue = "Subscribed to in-app notifications"
    }
    
    func onUnsubscribe(){
        guard delegate.notificationsHelper?.isSubscribed() == true else {
            print("I am not subscribed. Go away")
            return
        }
        
        delegate.notificationsHelper?.unsubscribe()
        print("Unsubscribing from in-app notifications")
        topLabel.stringValue = "Unsubscribed from in-app notifications"
    }
    
    func myNotificationHandler(notificationId: String, body: Any) {
        
        let sv = NSStackView(frame: NSRect(x: 100, y: 100, width: 100, height: 100))
        sv.userInterfaceLayoutDirection = NSUserInterfaceLayoutDirection.leftToRight
        
        let newLabel = NSTextField(frame: NSRect(x: 100, y: 100, width: 100, height: 100))
        newLabel.isEditable = false;
        newLabel.stringValue = notificationId.debugDescription + ": " + "\(body)"
        
        sv.addView(newLabel, in: NSStackViewGravity.leading)
        
        let button = NSButton(frame: NSRect(x: 100, y: 100, width: 100, height: 100))
        
        let handler = ClickHandler(handler: {
            self.delegate.notificationsHelper?.acknowledge(notificationId: notificationId)
            button.title = "Acknowledged!"
        });
        self.handlers.append(handler)  // DISGRACE: keep strong reference
        
        button.title = "Acknowledge"
        button.target = handler  // DISGRACE: button.target is a weak reference
        button.action = #selector(handler.buttonClick)
        
        
        sv.addView(button, in: NSStackViewGravity.leading)
        
        DispatchQueue.main.async {
            self.stackView.addView(sv, in: NSStackViewGravity.top)
        }
        
        print("Received user notification: " + notificationId.debugDescription)
    }
    
    func onRegister(){
//        delegate.notificationsHelper!.register(deviceToken: delegate.notificationsHelper!.deviceToken!)
        print("onRegister")
    }
    
    func onUnRegister(){
        print("onUnregister")
    }

    override var representedObject: Any? {
        didSet {}
    }
}
