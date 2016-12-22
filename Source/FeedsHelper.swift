import Foundation

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
        onError: ((Error) -> Void)? = nil,
        onStateChange: ((ResumableSubscriptionState, ResumableSubscriptionState) -> Void)? = nil,
        completionHandler: ((Result<ResumableSubscription>) -> Void)? = nil) -> Void {
            guard self.app != nil else {
                completionHandler?(.failure(ServiceHelperError.noAppObject))
                return
            }

            let path = "/\(FeedsHelper.namespace)/\(self.feedName)"

            let onUnderlyingSubscriptionChange: ((Subscription?, Subscription?) -> Void)? = { oldSub, newSub in
                self.subscriptionTaskId = newSub?.taskIdentifier
            }

            if lastEventId != nil {
                let headers = ["Last-Event-ID": lastEventId!]
                let subscribeRequest = SubscribeRequest(path: path, headers: headers)

                self.app!.subscribeWithResume(
                    using: subscribeRequest,
                    onOpen: onOpen,
                    onEvent: onAppend,
                    onEnd: onEnd,
                    onError: onError,
                    onStateChange: onStateChange,
                    onUnderlyingSubscriptionChange: onUnderlyingSubscriptionChange
                ) { result in
                        guard let subscription = result.value else {
                            completionHandler?(.failure(result.error!))
                            return
                        }
                        completionHandler?(.success(subscription))
                }
            } else {
                self.get() { result in
                    switch result {
                    case .failure(let error):
                        completionHandler?(.failure(error))
                    case .success(let feedsGetRes):
                        for item in feedsGetRes.items.reversed() {
                            guard let itemId = item["id"] as? String else {
                                // TODO: Add some debug logging
                                continue
                            }

                            // TODO: We don't always want to call onAppend, I imagine, maybe never in fact
                            onAppend?(itemId, [:], item["data"] as Any)
                        }

                        var headers: [String: String] = [:]
                        let mostRecentlyReceivedItemId = feedsGetRes.items.first?["id"] as? String

                        if mostRecentlyReceivedItemId != nil {
                            headers["Last-Event-ID"] = mostRecentlyReceivedItemId!
                        }

                        let subscribeRequest = SubscribeRequest(path: path, headers: headers)

                        self.app!.subscribeWithResume(
                            using: subscribeRequest,
                            onOpen: onOpen,
                            onEvent: onAppend,
                            onEnd: onEnd,
                            onError: onError,
                            onStateChange: onStateChange,
                            onUnderlyingSubscriptionChange: onUnderlyingSubscriptionChange
                        ) { result in
                                guard let subscription = result.value else {
                                    completionHandler?(.failure(result.error!))
                                    return
                                }
                                completionHandler?(.success(subscription))
                        }
                    }
                }
            }
    }

    public func subscribe(
        lastEventId: String? = nil,
        onOpen: (() -> Void)? = nil,
        onAppend: ((String, [String: String], Any) -> Void)? = nil,
        onEnd: ((Int?, [String: String]?, Any?) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil,
        completionHandler: ((Result<Subscription>) -> Void)? = nil) -> Void { // TODO: should the completion handler be required?
            guard self.app != nil else {
                completionHandler?(.failure(ServiceHelperError.noAppObject))
                return
            }

            let path = "/\(FeedsHelper.namespace)/\(self.feedName)"

            if lastEventId != nil {
                let headers = ["Last-Event-ID": lastEventId!]
                let subscribeRequest = SubscribeRequest(path: path, headers: headers)

                self.app!.subscribe(
                    using: subscribeRequest,
                    onOpen: onOpen,
                    onEvent: onAppend,
                    onEnd: onEnd,
                    onError: onError
                ) { result in
                    guard let subscription = result.value else {
                        completionHandler?(.failure(result.error!))
                        return
                    }

                    //TODO: does this need to be here?
                    self.subscriptionTaskId = subscription.taskIdentifier

                    completionHandler?(.success(subscription))
                }
            } else {
                self.get() { result in
                    switch result {
                    case .failure(let error):
                        completionHandler?(.failure(error))
                    case .success(let feedsGetRes):
                        for item in feedsGetRes.items.reversed() {
                            guard let itemId = item["id"] as? String else {
                                // TODO: Probably throw an ppropriate error here
                                continue
                            }

                            // TODO: We don't always want to call onAppend, I imagine, maybe never in fact
                            onAppend?(itemId, [:], item["data"] as Any)
                        }

                        var headers: [String: String] = [:]
                        let mostRecentlyReceivedItemId = feedsGetRes.items.first?["id"] as? String

                        if mostRecentlyReceivedItemId != nil {
                            headers["Last-Event-ID"] = mostRecentlyReceivedItemId!
                        }

                        let subscribeRequest = SubscribeRequest(path: path, headers: headers)

                        self.app!.subscribe(
                            using: subscribeRequest,
                            onOpen: onOpen,
                            onEvent: onAppend,
                            onEnd: onEnd,
                            onError: onError
                        ) { result in
                                guard let subscription = result.value else {
                                    completionHandler?(.failure(result.error!))
                                    return
                                }

                                //TODO: does this need to be here?
                                self.subscriptionTaskId = subscription.taskIdentifier

                                completionHandler?(.success(subscription))
                        }
                    }
                }
            }
    }

    public func get(from: String? = nil, limit: Int = 50, completionHandler: ((Result<FeedsItemsReponse>) -> Void)? = nil) -> Void {
        guard self.app != nil else {
            completionHandler?(.failure(ServiceHelperError.noAppObject))
            return
        }

        let path = "/\(FeedsHelper.namespace)/\(self.feedName)"

        var queryItems = [URLQueryItem(name: "limit", value: "\(limit)")]

        if from != nil {
            queryItems.append(URLQueryItem(name: "from_id", value: from!))
        }

        let generalRequest = GeneralRequest(method: "GET", path: path, queryItems: queryItems)

        self.app!.request(using: generalRequest) { result in
            guard let data = result.value else {
                completionHandler?(.failure(result.error!))
                return
            }

            guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) else {
                completionHandler?(.failure(FeedsHelperError.failedToDeserializeJSON(data)))
                return
            }

            guard let json = jsonObject as? [String: Any] else {
                completionHandler?(.failure(FeedsHelperError.failedToCastJSONObjectToDictionary(jsonObject)))
                return
            }

            guard let items = json["items"] as? [[String: Any]] else {
                completionHandler?(.failure(FeedsHelperError.itemsMissingFromJSONResponse(json)))
                return
            }

            if let id = json["next_id"] as? String {
                completionHandler?(.success(FeedsItemsReponse(nextId: id, items: items)))
            } else {
                completionHandler?(.success(FeedsItemsReponse(items: items)))
            }
        }
    }

    public func append(items: [Any], completionHandler: ((Result<String>) -> Void)? = nil) -> Void {
        guard self.app != nil else {
            completionHandler?(.failure(ServiceHelperError.noAppObject))
            return
        }

        let wrappedItems: [String: Any] = ["items": items]

        guard JSONSerialization.isValidJSONObject(wrappedItems) else {
            completionHandler?(.failure(ServiceHelperError.invalidJSONObjectAsData(wrappedItems)))
            return
        }

        guard let data = try? JSONSerialization.data(withJSONObject: wrappedItems, options: []) else {
            completionHandler?(.failure(ServiceHelperError.failedToJSONSerializeData(wrappedItems)))
            return
        }

        let path = "/\(FeedsHelper.namespace)/\(self.feedName)"

        let generalRequest = GeneralRequest(method: "APPEND", path: path, body: data)

        self.app!.request(using: generalRequest) { result in
            guard let data = result.value else {
                completionHandler?(.failure(result.error!))
                return
            }

            guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) else {
                completionHandler?(.failure(FeedsHelperError.failedToDeserializeJSON(data)))
                return
            }

            guard let json = jsonObject as? [String: Any] else {
                completionHandler?(.failure(FeedsHelperError.failedToCastJSONObjectToDictionary(jsonObject)))
                return
            }

            guard let id = json["item_id"] as? String else {
                completionHandler?(.failure(FeedsHelperError.failedToParseJSONResponse(json)))
                return
            }

            completionHandler?(.success(String(id)))
        }
    }

    public func append(item: Any, completionHandler: ((Result<String>) -> Void)? = nil) -> Void {
        self.append(items: [item], completionHandler: completionHandler)
    }

}

@objc public class FeedsItemsReponse: NSObject {
    public let nextId: String?
    public let items: [[String: Any]]

    public init(nextId: String? = nil, items: [[String: Any]]) {
        self.nextId = nextId
        self.items = items
    }
}

public enum FeedsHelperError: Error {
    case noSubscriptionTaskIdentifier
    case failedToDeserializeJSON(Data)
    case failedToCastJSONObjectToDictionary(Any)
    case failedToParseJSONResponse([String: Any])
    case itemsMissingFromJSONResponse([String: Any])
}
