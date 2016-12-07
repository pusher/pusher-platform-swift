import PromiseKit

@objc public class FeedsHelper: NSObject, ServiceHelper {
    static public let namespace = "feeds"

    public weak var app: App? = nil
    public let feedName: String

    public var subscriptionTaskId: Int? = nil

    public init(_ name: String, app: App) {
        self.feedName = name
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
        lastEventId: String? = nil,
        onOpen: (() -> Void)? = nil,
        onAppend: ((String, [String: String], Any) -> Void)? = nil,
        onEnd: ((Int?, [String: String]?, Any?) -> Void)? = nil,
        onStateChange: ((ResumableSubscriptionState, ResumableSubscriptionState) -> Void)? = nil) throws -> Promise<ResumableSubscription> {
            guard self.app != nil else {
                throw ServiceHelperError.noAppObject
            }

            let path = "/\(FeedsHelper.namespace)/\(self.feedName)"

            // TODO: should this be unowned self?
            let onUnderlyingSubscriptionChange: ((Subscription?, Subscription?) -> Void)? = { oldSub, newSub in
                self.subscriptionTaskId = newSub?.taskIdentifier
            }

            if lastEventId != nil {

                let headers = ["Last-Event-ID": lastEventId!]

                // TODO: should this be unowned self?
                let onUnderlyingSubscriptionChange: ((Subscription?, Subscription?) -> Void)? = { oldSub, newSub in
                    self.subscriptionTaskId = newSub?.taskIdentifier
                }

                return try! self.app!.subscribeWithResume(
                    path: path,
                    jwt: nil,
                    headers: headers,
                    onOpen: onOpen,
                    onEvent: onAppend,
                    onEnd: onEnd,
                    onStateChange: onStateChange,
                    onUnderlyingSubscriptionChange: onUnderlyingSubscriptionChange
                )
            } else {
                return try! self.get().then { feedsGetRes in
                    for item in feedsGetRes.items.reversed() {
                        guard let itemId = item["id"] as? String else {
                            // TODO: Probably throw an ppropriate error here
                            continue
                        }

                        onAppend?(itemId, [:], item["data"])
                    }

                    var headers: [String: String] = [:]
                    var mostRecentlyReceivedItemId = feedsGetRes.items.first?["id"] as? String

                    if mostRecentlyReceivedItemId != nil {
                        headers["Last-Event-ID"] = mostRecentlyReceivedItemId!
                    }

                    return try! self.app!.subscribeWithResume(
                        path: path,
                        jwt: nil,
                        headers: headers,
                        onOpen: onOpen,
                        onEvent: onAppend,
                        onEnd: onEnd,
                        onStateChange: onStateChange,
                        onUnderlyingSubscriptionChange: onUnderlyingSubscriptionChange
                    )
                }
            }
    }

    public func subscribe(
        lastEventId: String? = nil,
        onOpen: (() -> Void)? = nil,
        onAppend: ((String, [String: String], Any) -> Void)? = nil,
        onEnd: ((Int?, [String: String]?, Any?) -> Void)? = nil) throws -> Promise<Subscription> {
            guard self.app != nil else {
                throw ServiceHelperError.noAppObject
            }

            let path = "/\(FeedsHelper.namespace)/\(self.feedName)"

            if lastEventId != nil {

                let headers = ["Last-Event-ID": lastEventId!]

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
            } else {
                return try! self.get().then { feedsGetRes in
                    for item in feedsGetRes.items.reversed() {
                        guard let itemId = item["id"] as? String else {
                            // TODO: Probably throw an ppropriate error here
                            continue
                        }

                        onAppend?(itemId, [:], item["data"])
                    }

                    var headers: [String: String] = [:]
                    var mostRecentlyReceivedItemId = feedsGetRes.items.first?["id"] as? String

                    if mostRecentlyReceivedItemId != nil {
                        headers["Last-Event-ID"] = mostRecentlyReceivedItemId!
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
            }
    }

    public func get(from: String? = nil, limit: Int = 50) throws -> Promise<FeedsItemsReponse> {
        guard self.app != nil else {
            throw ServiceHelperError.noAppObject
        }

        let path = "/\(FeedsHelper.namespace)/\(self.feedName)"

        var queryItems = [URLQueryItem(name: "limit", value: "\(limit)")]

        if from != nil {
            queryItems.append(URLQueryItem(name: "from_id", value: from!))
        }

        return self.app!.request(method: "GET", path: path, queryItems: queryItems).then { data -> Promise<FeedsItemsReponse> in
            return Promise<FeedsItemsReponse> { fulfill, reject in
                guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                    reject(FeedsHelperError.failedToDeserializeJSON(data))
                    return
                }

                guard let items = json["items"] as? [[String: Any]] else {
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
    public let items: [[String: Any]]

    public init(nextId: Int? = nil, items: [[String: Any]]) {
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
