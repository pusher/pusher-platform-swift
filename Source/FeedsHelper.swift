import Foundation

@objc public class FeedsHelper: NSObject, ServiceHelper {
    static public let namespace = "feeds"

    public weak var app: App? = nil
    public let feedName: String

    // TODO: Maybe need to sort out making sure that you can't subscribe if
    // subscription already exists, or make sure that you can't subscribeWithResume
    // if a Subscription already exists, and likewise with not being able to call
    // subscribe if a ResumableSubscription alreading exists
    public internal(set) var subscription: Subscription? = nil
    public internal(set) var resumableSubscription: ResumableSubscription? = nil

    public internal(set) var nextIdForFetchingOlderItems: String? = nil
    public internal(set) var moreItemsToFetch: Bool = true

    public init(_ name: String, app: App) {
        self.feedName = name
        self.app = app
    }

    public func fetchOlderItems(from id: String? = nil, limit: Int? = nil, completionHandler: @escaping (Result<[[String: Any]]>) -> Void) {
        guard self.moreItemsToFetch else {
            DefaultLogger.Logger.log(message: "No older items to fetch in feed: \(self.feedName)")
            completionHandler(.success([]))
            return
        }

        let idToFetchFrom = id ?? self.nextIdForFetchingOlderItems

        self.get(from: idToFetchFrom, limit: limit) { result in
            switch result {
            case .failure(let error):
                completionHandler(.failure(error))
            case .success(let feedsGetRes):
                completionHandler(.success(feedsGetRes.items))
            }
        }
    }

    public func unsubscribe(completionHandler: ((Result<Bool>) -> Void)? = nil) {
        guard self.app != nil else {
            completionHandler?(.failure(ServiceHelperError.noAppObject))
            return
        }

        guard self.subscription != nil || self.resumableSubscription != nil else {
            completionHandler?(.failure(FeedsHelperError.noSubscriptionOrResumableSubscription))
            return
        }

        if let subscription = self.subscription {
            guard let taskId = subscription.taskIdentifier else {
                completionHandler?(.failure(FeedsHelperError.taskIdentifierForSubscriptionNotPresent(subscription)))
                return
            }

            self.app!.unsubscribe(taskIdentifier: taskId, completionHandler: completionHandler)
        } else if let resumableSubscription = self.resumableSubscription {
            guard let subscription = self.resumableSubscription?.subscription else {
                completionHandler?(.failure(FeedsHelperError.underlyingSubscriptionForResumableSubscriptionNotPresent(resumableSubscription)))
                return
            }

            guard let taskId = subscription.taskIdentifier else {
                completionHandler?(.failure(FeedsHelperError.taskIdentifierForSubscriptionNotPresent(subscription)))
                return
            }

            resumableSubscription.changeState(to: .closing)
            resumableSubscription.unsubscribed = true
            self.app!.unsubscribe(taskIdentifier: taskId, completionHandler: completionHandler)
        }
    }

    public func subscribeWithResume(
        lastEventId: String? = nil,
        onOpen: (() -> Void)? = nil,
        onAppend: ((String, [String: String], Any) -> Void)? = nil,
        onEnd: ((Int?, [String: String]?, Any?) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil,
        onStateChange: ((ResumableSubscriptionState, ResumableSubscriptionState) -> Void)? = nil,
        completionHandler: ((Result<ResumableSubscription>) -> Void)? = nil) {
            guard self.app != nil else {
                completionHandler?(.failure(ServiceHelperError.noAppObject))
                return
            }

            let path = "/\(FeedsHelper.namespace)/\(self.feedName)"

            if lastEventId != nil {
                let headers = ["Last-Event-ID": lastEventId!]
                let subscribeRequest = SubscribeRequest(path: path, headers: headers)

                self.app!.subscribeWithResume(
                    using: subscribeRequest,
                    onOpen: onOpen,
                    onEvent: onAppend,
                    onEnd: onEnd,
                    onError: onError,
                    onStateChange: onStateChange
                ) { result in
                        guard let resumableSubscription = result.value else {
                            completionHandler?(.failure(result.error!))
                            return
                        }

                        self.resumableSubscription = resumableSubscription
                        completionHandler?(.success(resumableSubscription))
                }
            } else {
                self.get() { result in
                    switch result {
                    case .failure(let error):
                        completionHandler?(.failure(error))
                    case .success(let feedsGetRes):
                        for item in feedsGetRes.items.reversed() {
                            guard let itemId = item["id"] as? String else {
                                DefaultLogger.Logger.log(message: "Item received without an id \(item)")
                                continue
                            }

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
                            onStateChange: onStateChange
                        ) { result in
                                guard let resumableSubscription = result.value else {
                                    completionHandler?(.failure(result.error!))
                                    return
                                }

                                self.resumableSubscription = resumableSubscription
                                completionHandler?(.success(resumableSubscription))
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
        // TODO: should the completion handler be required?
        completionHandler: ((Result<Subscription>) -> Void)? = nil) {
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

                        self.subscription = subscription
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
                                DefaultLogger.Logger.log(message: "Item received without an id \(item)")
                                continue
                            }

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

                                self.subscription = subscription
                                completionHandler?(.success(subscription))
                        }
                    }
                }
            }
    }

    public func get(from id: String? = nil, limit: Int? = 50, completionHandler: ((Result<FeedsItemsReponse>) -> Void)? = nil) {
        guard self.app != nil else {
            completionHandler?(.failure(ServiceHelperError.noAppObject))
            return
        }

        let path = "/\(FeedsHelper.namespace)/\(self.feedName)"

        var queryItems = (limit != nil) ? [URLQueryItem(name: "limit", value: "\(limit!)")] : []

        if let id = id {
            queryItems.append(URLQueryItem(name: "from_id", value: id))
        }

        let generalRequest = GeneralRequest(method: HttpMethod.GET.rawValue, path: path, queryItems: queryItems)

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
                self.nextIdForFetchingOlderItems = id
                completionHandler?(.success(FeedsItemsReponse(nextId: id, items: items)))
            } else {
                self.moreItemsToFetch = false
                completionHandler?(.success(FeedsItemsReponse(items: items)))
            }
        }
    }

    public func append(items: [Any], completionHandler: ((Result<String>) -> Void)? = nil) {
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

        let generalRequest = GeneralRequest(method: HttpMethod.APPEND.rawValue, path: path, body: data)

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
                completionHandler?(.failure(FeedsHelperError.itemIdNotFoundInResponseJSON(json)))
                return
            }

            completionHandler?(.success(String(id)))
        }
    }

    public func append(item: Any, completionHandler: ((Result<String>) -> Void)? = nil) {
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
    case noSubscriptionOrResumableSubscription
    case failedToDeserializeJSON(Data)
    case failedToCastJSONObjectToDictionary(Any)
    case itemIdNotFoundInResponseJSON([String: Any])
    case itemsMissingFromJSONResponse([String: Any])
    case taskIdentifierForSubscriptionNotPresent(Subscription)
    case underlyingSubscriptionForResumableSubscriptionNotPresent(ResumableSubscription)
}
