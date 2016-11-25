//
//  FeedsHelper.swift
//  ElementsSwift
//
//  Created by Hamilton Chapman on 05/10/2016.
//
//

import PromiseKit

@objc public class FeedsHelper: NSObject, ServiceHelper {
    // TODO: should this be here?
    static internal let namespace = "feeds"

    public weak var app: ElementsApp? = nil
    public let feedName: String

    public init(feedName: String, app: ElementsApp) {
        self.feedName = feedName
        self.app = app
    }

    public func subscribe(lastEventId: String? = nil) throws -> Promise<Subscription> {
        guard self.app != nil else {
            // TODO: this is wrong - just did it to make it compile
            throw ServiceHelperError.noAppObject
        }

        // TODO: tidy up
        let path = "/\(FeedsHelper.namespace)/\(self.feedName)"
        var headers: [String: String]? = nil

        if lastEventId != nil {
            headers = ["Last-Event-ID": lastEventId!]
        }

        return try! self.app!.subscribe(path: path, jwt: nil, headers: headers)
    }

    public func get(from: String, limit: Int = 50) throws -> Promise<FeedsItemsReponse> {
        guard self.app != nil else {
            throw ServiceHelperError.noAppObject
        }

        let path = "/\(FeedsHelper.namespace)/\(self.feedName)"

        return self.app!.request(method: "GET", path: path).then { data -> Promise<FeedsItemsReponse> in
            return Promise<FeedsItemsReponse> { fulfill, reject in
                guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                    reject(FeedsHelperError.failedToDeserializeJSON(data))
                    return
                }

                // TODO: check what the keys are going to be
                // TODO: check what happens with response if there is no next id
                guard let id = json["id"] as? String, let items = json["items"] as? [Any] else {
                    reject(FeedsHelperError.failedToParseJSONResponse(json))
                    return
                }

                fulfill(FeedsItemsReponse(nextOlderId: id, items: items))
            }
        }
    }

    public func append(item: Any) throws -> Promise<String> {
        guard self.app != nil else {
            throw ServiceHelperError.noAppObject
        }

        guard JSONSerialization.isValidJSONObject(item) else {
            throw ServiceHelperError.invalidJSONObjectAsData(item)
        }

        guard let data = try? JSONSerialization.data(withJSONObject: item, options: []) else {
            throw ServiceHelperError.failedToJSONSerializeData(item)
        }

        let path = "/\(FeedsHelper.namespace)/\(self.feedName)"

        return self.app!.request(method: "APPEND", path: path, jwt: nil, headers: nil, body: data).then { data -> Promise<String> in
            return Promise<String> { fulfill, reject in
                guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                    reject(FeedsHelperError.failedToDeserializeJSON(data))
                    return
                }

                // TODO: check what the key is going to be
                guard let id = json["id"] as? String else {
                    reject(FeedsHelperError.failedToParseJSONResponse(json))
                    return
                }

                fulfill(id)
            }
        }
    }
}

@objc public class FeedsItemsReponse: NSObject {
    public let nextOlderId: String?
    public let items: [Any]

    public init(nextOlderId: String? = nil, items: [Any]) {
        self.nextOlderId = nextOlderId
        self.items = items
    }
}

public enum FeedsHelperError: Error {
    case failedToDeserializeJSON(Data)
    case failedToParseJSONResponse([String: Any])
}
