import Foundation

@objc public class Feed: NSObject, Service {
    static public let namespace = "feeds"

    public weak var app: App? = nil
    public let feedName: String

    // TODO: Maybe need to sort out making sure that you can't subscribe if
    // subscription already exists, or make sure that you can't subscribeWithResume
    // if a Subscription already exists, and likewise with not being able to call
    // subscribe if a ResumableSubscription already exists
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
            completionHandler?(.failure(ServiceError.noAppObject))
            return
        }

        guard self.subscription != nil || self.resumableSubscription != nil else {
            completionHandler?(.failure(FeedError.noSubscriptionOrResumableSubscription))
            return
        }

        if let subscription = self.subscription {
            guard let taskId = subscription.taskIdentifier else {
                completionHandler?(.failure(FeedError.taskIdentifierForSubscriptionNotPresent(subscription)))
                return
            }

            self.app!.unsubscribe(taskIdentifier: taskId, completionHandler: completionHandler)

            // TODO: where do we set this to nil?
            self.subscription = nil
        } else if let resumableSubscription = self.resumableSubscription {
            guard let subscription = self.resumableSubscription?.subscription else {
                completionHandler?(.failure(FeedError.underlyingSubscriptionForResumableSubscriptionNotPresent(resumableSubscription)))
                return
            }

            guard let taskId = subscription.taskIdentifier else {
                completionHandler?(.failure(FeedError.taskIdentifierForSubscriptionNotPresent(subscription)))
                return
            }

            resumableSubscription.unsubscribed = true
            resumableSubscription.changeState(to: .ended)
            self.app!.unsubscribe(taskIdentifier: taskId, completionHandler: completionHandler)

            // TODO: where do we set this to nil?
            self.resumableSubscription = nil
        }
    }

    @discardableResult
    public func subscribe(
        lastEventId: String? = nil,
        onOpening: (() -> Void)? = nil,
        onOpen: (() -> Void)? = nil,
        onResuming: (() -> Void)? = nil,
        onAppend: ((String, [String: String], Any) -> Void)? = nil,
        onEnd: ((Int?, [String: String]?, Any?) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil) -> ResumableSubscription {
            guard self.app != nil else {
                // TODO: Is fatalError the correct behaviour here? Maybe we just call onError as usual?
                fatalError("App object is nil. This likely means that you've not correctly retained it.")
            }

            let path = "/\(Feed.namespace)/\(self.feedName)"
            var resumableSub = ResumableSubscription(
                app: self.app!,
                path: path,
                onOpening: onOpening,
                onOpen: onOpen,
                onResuming: onResuming,
                onEvent: onAppend,
                onEnd: onEnd,
                onError: onError
            )

            self.resumableSubscription = resumableSub

            if lastEventId != nil {
                let headers = ["Last-Event-ID": lastEventId!]
                let subscribeRequest = SubscribeRequest(path: path, headers: headers)

                self.app!.subscribeWithResume(
                    resumableSubscription: &resumableSub,
                    using: subscribeRequest,
                    onOpening: onOpening,
                    onOpen: onOpen,
                    onResuming: onResuming,
                    onEvent: onAppend,
                    onEnd: onEnd,
                    onError: onError
                )
            } else {
                self.get() { result in
                    switch result {
                    case .failure(let error):
                        onError?(error)
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
                            resumableSubscription: &resumableSub,
                            using: subscribeRequest,
                            onOpening: onOpening,
                            onOpen: onOpen,
                            onResuming: onResuming,
                            onEvent: onAppend,
                            onEnd: onEnd,
                            onError: onError
                        )
                    }
                }
            }

            return resumableSub
    }

    public func get(from id: String? = nil, limit: Int? = 50, completionHandler: ((Result<FeedItemsReponse>) -> Void)? = nil) {
        guard self.app != nil else {
            completionHandler?(.failure(ServiceError.noAppObject))
            return
        }

        let path = "/\(Feed.namespace)/\(self.feedName)"

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
                completionHandler?(.failure(FeedError.failedToDeserializeJSON(data)))
                return
            }

            guard let json = jsonObject as? [String: Any] else {
                completionHandler?(.failure(FeedError.failedToCastJSONObjectToDictionary(jsonObject)))
                return
            }

            guard let items = json["items"] as? [[String: Any]] else {
                completionHandler?(.failure(FeedError.itemsMissingFromJSONResponse(json)))
                return
            }

            if let id = json["next_id"] as? String {
                self.nextIdForFetchingOlderItems = id
                completionHandler?(.success(FeedItemsReponse(nextId: id, items: items)))
            } else {
                self.moreItemsToFetch = false
                completionHandler?(.success(FeedItemsReponse(items: items)))
            }
        }
    }

    public func append(items: [Any], completionHandler: ((Result<String>) -> Void)? = nil) {
        guard self.app != nil else {
            completionHandler?(.failure(ServiceError.noAppObject))
            return
        }

        let wrappedItems: [String: Any] = ["items": items]

        guard JSONSerialization.isValidJSONObject(wrappedItems) else {
            completionHandler?(.failure(ServiceError.invalidJSONObjectAsData(wrappedItems)))
            return
        }

        guard let data = try? JSONSerialization.data(withJSONObject: wrappedItems, options: []) else {
            completionHandler?(.failure(ServiceError.failedToJSONSerializeData(wrappedItems)))
            return
        }

        let path = "/\(Feed.namespace)/\(self.feedName)"

        let generalRequest = GeneralRequest(method: HttpMethod.POST.rawValue, path: path, body: data)

        self.app!.request(using: generalRequest) { result in
            guard let data = result.value else {
                completionHandler?(.failure(result.error!))
                return
            }

            guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) else {
                completionHandler?(.failure(FeedError.failedToDeserializeJSON(data)))
                return
            }

            guard let json = jsonObject as? [String: Any] else {
                completionHandler?(.failure(FeedError.failedToCastJSONObjectToDictionary(jsonObject)))
                return
            }

            guard let id = json["item_id"] as? String else {
                completionHandler?(.failure(FeedError.itemIdNotFoundInResponseJSON(json)))
                return
            }

            completionHandler?(.success(String(id)))
        }
    }

    public func append(item: Any, completionHandler: ((Result<String>) -> Void)? = nil) {
        self.append(items: [item], completionHandler: completionHandler)
    }

}

@objc public class FeedItemsReponse: NSObject {
    public let nextId: String?
    public let items: [[String: Any]]

    public init(nextId: String? = nil, items: [[String: Any]]) {
        self.nextId = nextId
        self.items = items
    }
}

public enum FeedError: Error {
    case noSubscriptionOrResumableSubscription
    case failedToDeserializeJSON(Data)
    case failedToCastJSONObjectToDictionary(Any)
    case itemIdNotFoundInResponseJSON([String: Any])
    case itemsMissingFromJSONResponse([String: Any])
    case taskIdentifierForSubscriptionNotPresent(Subscription)
    case underlyingSubscriptionForResumableSubscriptionNotPresent(ResumableSubscription)
}
