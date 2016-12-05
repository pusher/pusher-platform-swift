import PromiseKit

@objc public class FeedsHelper: NSObject, ServiceHelper {
    static public let namespace = "feeds"

    public weak var app: ElementsApp? = nil
    public let feedName: String

    // TODO: how does this work with ResumableSubscription - how do we pass the new 
    // task id to the FeedsHelper when a new underlying Subscription is created?
    public var subscriptionTaskId: Int? = nil

    public init(feedName: String, app: ElementsApp) {
        self.feedName = feedName
        self.app = app
    }

    public func unsubscribe() throws {
        guard self.app != nil else {
            throw ServiceHelperError.noAppObject
        }

        guard self.subscriptionTaskId != nil else {
            throw FeedsHelperError.noSubscriptionTaskIdentifier
        }

        self.app!.unsubscribe(taskIdentifier: subscriptionTaskId!)
    }

    public func subscribeWithResume(
        onOpen: (() -> Void)? = nil,
        onAppend: ((String, [String: String], Any) -> Void)? = nil,
        onEnd: ((Int?, [String: String]?, Any?) -> Void)? = nil,
        onStateChange: ((ResumableSubscriptionState, ResumableSubscriptionState) -> Void)? = nil,
        lastEventId: String? = nil) throws -> Promise<ResumableSubscription> {
            guard self.app != nil else {
                throw ServiceHelperError.noAppObject
            }

            let path = "/\(FeedsHelper.namespace)/\(self.feedName)"

            var headers: [String: String]? = nil

            if lastEventId != nil {
                headers = ["Last-Event-ID": lastEventId!]
            }

            return try! self.app!.subscribeWithResume(
                path: path,
                jwt: nil,
                headers: headers,
                onOpen: onOpen,
                onEvent: onAppend,
                onEnd: onEnd,
                onStateChange: onStateChange
            )
    }

    public func subscribe(
        onOpen: (() -> Void)? = nil,
        onAppend: ((String, [String: String], Any) -> Void)? = nil,
        onEnd: ((Int?, [String: String]?, Any?) -> Void)? = nil,
        lastEventId: String? = nil) throws -> Promise<Subscription> {
            guard self.app != nil else {
                throw ServiceHelperError.noAppObject
            }

            let path = "/\(FeedsHelper.namespace)/\(self.feedName)"

            var headers: [String: String]? = nil

            if lastEventId != nil {
                headers = ["Last-Event-ID": lastEventId!]
            }

            return try! self.app!.subscribe(
                path: path,
                jwt: nil,
                headers: headers,
                onOpen: onOpen,
                onEvent: onAppend,
                onEnd: onEnd
            ).then { sub -> Promise<Subscription> in
                // TODO: there must be a better way that re-wrapping the subscription in a Promise, surely!
                self.subscriptionTaskId = sub.taskIdentifier
                return Promise<Subscription> { fulfill, reject in
                    fulfill(sub)
                }
            }
    }

    public func get(from: String, limit: Int = 50) throws -> Promise<FeedsItemsReponse> {
        guard self.app != nil else {
            throw ServiceHelperError.noAppObject
        }

        let path = "/\(FeedsHelper.namespace)/\(self.feedName)"

        let queryItems = [URLQueryItem(name: "from_id", value: from), URLQueryItem(name: "limit", value: "\(limit)")]

        return self.app!.request(method: "GET", path: path, queryItems: queryItems).then { data -> Promise<FeedsItemsReponse> in
            return Promise<FeedsItemsReponse> { fulfill, reject in
                guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                    reject(FeedsHelperError.failedToDeserializeJSON(data))
                    return
                }

                guard let items = json["items"] as? [Any] else {
                    reject(FeedsHelperError.itemsMissingFromJSONResponse(json))
                    return
                }

                // TODO: make the id a string when Will has made changes
                if let id = json["next_id"] as? Int {
                    fulfill(FeedsItemsReponse(nextId: id, items: items))
                } else {
                    fulfill(FeedsItemsReponse(items: items))
                }
            }
        }
    }

    public func append(item: Any) throws -> Promise<String> {
        guard self.app != nil else {
            throw ServiceHelperError.noAppObject
        }

        let wrappedItem: [String: Any] = ["data": item]

        guard JSONSerialization.isValidJSONObject(wrappedItem) else {
            throw ServiceHelperError.invalidJSONObjectAsData(wrappedItem)
        }

        guard let data = try? JSONSerialization.data(withJSONObject: wrappedItem, options: []) else {
            throw ServiceHelperError.failedToJSONSerializeData(item)
        }

        let path = "/\(FeedsHelper.namespace)/\(self.feedName)"

        return self.app!.request(method: "APPEND", path: path, jwt: nil, headers: nil, body: data).then { data -> Promise<String> in
            return Promise<String> { fulfill, reject in
                guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                    reject(FeedsHelperError.failedToDeserializeJSON(data))
                    return
                }

                // TODO: change this to be a String when Will has made the changes
                guard let id = json["item_id"] as? Int else {
                    reject(FeedsHelperError.failedToParseJSONResponse(json))
                    return
                }

                fulfill(String(id))
            }
        }
    }
}

@objc public class FeedsItemsReponse: NSObject {
    // TODO: make id string when Will has made changes
    public let nextId: Int?
    public let items: [Any]

    public init(nextId: Int? = nil, items: [Any]) {
        self.nextId = nextId
        self.items = items
    }
}

public enum FeedsHelperError: Error {
    case noSubscriptionTaskIdentifier
    case failedToDeserializeJSON(Data)
    case failedToParseJSONResponse([String: Any])
    case itemsMissingFromJSONResponse([String: Any])
}
