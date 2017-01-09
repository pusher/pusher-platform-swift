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
    var app: App? = nil
    var feed: FeedsHelper? = nil
    var feedItems: [[String: String]] = []

    @IBOutlet weak var feedTableView: NSTableView!

    @IBAction func subscribeButton(_ sender: Any) {
        feed?.subscribeWithResume(
            onOpen: { Void in print("OPEN") },
            onAppend: { itemId, headers, item in
                print("RECEIVED: ", itemId, headers, item)
                if let item = item as? [String: String] {
                    self.feedItems.append(item)
                    self.reloadFeedTableView()
                } else {
                    print("Item not formed correctly: \(item)")
                }
            },
            onEnd: { statusCode, headers, info in print("END: ", statusCode, headers, info) },
            onError: { error in print("ERROR: ", error) },
            onStateChange: { oldState, newState in print("was \(oldState) now \(newState)") }
        )
    }

    @IBAction func unsubscribeButton(_ sender: Any) {
        feed?.unsubscribe()
    }

    @IBAction func fetchOlderItemsButton(_ sender: Any) {
        feed?.fetchOlderItems() { result in
            switch result {
            case .failure(let error):
                print("Error when fetching older items: \(error)")
            case .success(let items):
                print("***********************")
                print(items)
                let castItems = items.reversed().flatMap { $0["data"] as? [String: String] }
                self.feedItems = castItems + self.feedItems
                self.reloadFeedTableView()
            }
        }
    }

    @IBAction func appendRandomDataButton(_ sender: Any) {
        feed?.append(item: ["timestamp": String(Int(Date().timeIntervalSince1970)), "uuid": NSUUID().uuidString])
    }

    func reloadFeedTableView() {
        DispatchQueue.main.async {
            print("About to reload table view")
            self.feedTableView.reloadData()
        }
    }

    override func viewDidLoad() {
        self.feedTableView.dataSource = self
        self.feedTableView.delegate = self

        let authorizer = SimpleTokenAuthorizer(jwt: "some.relevant.jwt")
        app = try! App(id: "yourAppId", authorizer: authorizer)
        feed = app?.feeds("resumable-ham")
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
