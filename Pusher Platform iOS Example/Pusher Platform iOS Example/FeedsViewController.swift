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
    var feedItems: [[String: String]] = []

    @IBOutlet weak var feedTableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()
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
