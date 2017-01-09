//
//  FeedsViewController.swift
//  Elements iOS Example
//
//  Created by Zan Markan on 06/12/2016.
//  Copyright © 2016 Pusher. All rights reserved.
//

import UIKit

class FeedsViewController: UIViewController {

    @IBOutlet var feedLabel: UILabel!

    var delegate: AppDelegate!

    override func viewDidLoad() {
        super.viewDidLoad()
        print("Feeds ViewController")

        delegate = UIApplication.shared.delegate as! AppDelegate

        let feed = delegate.elements.feeds("resumable-ham")

        feed.subscribeWithResume(
            onOpen: { Void in print("OPEN") },
            onAppend: { itemId, headers, item in print("RECEIVED: ", itemId, headers, item) } ,
            onEnd: { statusCode, headers, info in print("END: ", statusCode, headers, info) },
            onError: { error in print("ERROR: ", error) },
            onStateChange: { oldState, newState in print("was \(oldState) now \(newState)") }
        ) { result in
            print("RESULT: ", result)
        }
    }
}
