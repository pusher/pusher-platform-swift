//
//  ViewController.swift
//  Pusher Platform macOS Example
//
//  Created by Hamilton Chapman on 27/09/2016.
//  Copyright © 2016 Pusher. All rights reserved.
//

import Cocoa
import PusherPlatform

class ViewController: NSViewController {
    var app: App? = nil
    var feedItems: [[String: String]] = []

    @IBOutlet weak var feedTableView: NSTableView!

    @IBAction func subscribeButton(_ sender: Any) {

    }

    @IBAction func unsubscribeButton(_ sender: Any) {

    }

    @IBAction func fetchOlderItemsButton(_ sender: Any) {

    }

    @IBAction func appendRandomDataButton(_ sender: Any) {

    }

    func reloadFeedTableView() {
        DispatchQueue.main.async {
            self.feedTableView.reloadData()
        }
    }

    override func viewDidLoad() {
        self.feedTableView.dataSource = self
        self.feedTableView.delegate = self

        app = App(id: "4ff02853-bfed-4590-80c7-40c09f25d113")
    }

    override var representedObject: Any? {
        didSet {}
    }
}

extension ViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.feedItems.count
    }
}

extension ViewController: NSTableViewDelegate {
    fileprivate enum CellIdentifiers {
        static let TimestampCell = "TimestampCellID"
        static let UUIDCell = "UUIDCellID"
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        var text: String = ""
        var cellIdentifier: String = ""

        let item = feedItems[row]

        if tableColumn == tableView.tableColumns[0] {
            text = item["timestamp"]!
            cellIdentifier = CellIdentifiers.TimestampCell
        } else if tableColumn == tableView.tableColumns[1] {
            text = item["uuid"]!
            cellIdentifier = CellIdentifiers.UUIDCell
        }

        if let cell = tableView.make(withIdentifier: cellIdentifier, owner: nil) as? NSTableCellView {
            cell.textField?.stringValue = text
            return cell
        }

        return nil
    }
}
