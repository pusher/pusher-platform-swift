//
//  FeedsViewController.swift
//  Pusher Platform iOS Example
//
//  Created by Zan Markan on 06/12/2016.
//  Copyright © 2016 Pusher. All rights reserved.
//

import UIKit

class FeedsViewController: UIViewController {
    @IBOutlet var feedLabel: UILabel!
    var delegate: AppDelegate!
    var feedItems: [[String: String]] = []

    @IBOutlet weak var feedTableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()
        print("Feeds ViewController")

        feedTableView.delegate = self
        feedTableView.dataSource = self
        feedTableView.register(UITableViewCell.self, forCellReuseIdentifier: "FeedItemCell")

        delegate = UIApplication.shared.delegate as! AppDelegate

        let feed = delegate.app.feed("gg")

        feed.subscribe(
            onOpening: { print("OPENING") },
            onOpen: { print("OPEN \(self.getTimeNow())") },
            onResuming: { print("RESUMING") },
            onAppend: { itemId, headers, item in print("RECEIVED: ", itemId, headers, item) },
            onEnd: { statusCode, headers, info in print("END \(self.getTimeNow()): ", statusCode, headers, info) },
            onError: { error in print("ERROR \(self.getTimeNow()): ", error) }
        )
    }
}

extension FeedsViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.feedItems.count
    }
}

extension FeedsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = feedTableView.dequeueReusableCell(withIdentifier: "FeedItemCell", for: indexPath)
        let item = feedItems[indexPath.row]

        cell.textLabel?.text = item["testing"]
        return cell
    }
}

extension FeedsViewController {
    func getTimeNow() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .long

        return formatter.string(from: Date())
    }
}
