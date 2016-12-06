//
//  UserNotificationsViewController.swift
//  Elements iOS Example
//
//  Created by Zan Markan on 06/12/2016.
//  Copyright © 2016 Pusher. All rights reserved.
//

import UIKit
import ElementsSwift

class UserNotificationsViewController: UIViewController {
    
    @IBOutlet var inAppLabel: UILabel!
    @IBOutlet var pushLabel: UILabel!
    
    @IBAction func subscribeButton(_ sender: Any) {
        subscribeToUserNotifications()
    }
    @IBAction func unsubscribeButton(_ sender: Any) {
        unsubscribeFromUserNotifications()
    }
    
    var delegate: AppDelegate!
    var elements: App!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("User NotificationsViewController")
        delegate = UIApplication.shared.delegate as! AppDelegate
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        
        print ("UserNotifications ViewController - viewDidAppear")
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func subscribeToUserNotifications() {
        guard delegate.notificationsHelper?.isSubscribed() == false else {
            print("I am already subscribed!")
            return
        }
            
        try! delegate.notificationsHelper?.subscribe(notificationHandler: myNotificationHandler, receiptHandler: { (notificationId: String) -> () in
                print("I was informed that user notification was read: \(notificationId.debugDescription)")
        })
    
        print("Subscribed to in-app notifications!")
        inAppLabel.text = "In-App: Subscribed"
    }
    
    func unsubscribeFromUserNotifications(){
        guard delegate.notificationsHelper?.isSubscribed() == true else {
            print("I am not subscribed")
            return
        }
        
        try! delegate.notificationsHelper?.unsubscribe()
        inAppLabel.text = "In-App: Not Subscribed"
    }
    
    
    func myNotificationHandler(notificationId: String, body: Any) {
        
        print("Received notification: \(notificationId.debugDescription)")
        
        
        
//        let sv = NSStackView(frame: NSRect(x: 100, y: 100, width: 100, height: 100))
//        sv.userInterfaceLayoutDirection = NSUserInterfaceLayoutDirection.leftToRight
//        
//        let newLabel = NSTextField(frame: NSRect(x: 100, y: 100, width: 100, height: 100))
//        newLabel.isEditable = false
//        newLabel.stringValue = "\(notificationId.debugDescription): \(body)"
//        
//        sv.addView(newLabel, in: NSStackViewGravity.leading)
//        
//        let button = NSButton(frame: NSRect(x: 100, y: 100, width: 100, height: 100))
//        
//        let handler = ClickHandler(handler: {
//            try! self.delegate.notificationsHelper?.acknowledge(notificationId: notificationId)
//            
//            button.title = "Acknowledged!"
//        })
//        
//        self.handlers.append(handler)  // DISGRACE: keep strong reference
//        
//        button.title = "Acknowledge"
//        button.target = handler  // DISGRACE: button.target is a weak reference
//        button.action = #selector(handler.buttonClick)
//        
//        
//        sv.addView(button, in: NSStackViewGravity.leading)
//        
//        DispatchQueue.main.async {
//            self.stackView.addView(sv, in: NSStackViewGravity.top)
//        }
//        
//        print("Received user notification: \(notificationId.debugDescription)")
    }
    
}
