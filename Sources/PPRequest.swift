import Foundation

public class PPRequest<Delegate: PPRequestTaskDelegate> {
    var delegate: Delegate

    // TODO: Could this be an associatedtype? Different options needed for different types of
    // request, e.g. download needs a destination, whereas others don't. Or can it all be
    // made part of the delegate?
    var options: PPRequestOptions? = nil

    public init(delegate: Delegate? = nil) {
        self.delegate = delegate ?? Delegate.init()
    }
}

public typealias PPSubscription = PPRequest<PPSubscriptionDelegate>
public typealias PPGeneralRequest = PPRequest<PPGeneralRequestDelegate>
public typealias PPUpload = PPRequest<PPUploadDelegate>
public typealias PPDownload = PPRequest<PPDownloadDelegate>
