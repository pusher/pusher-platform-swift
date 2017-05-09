import UIKit
import PusherPlatform

class ViewController: UIViewController {

    var app: App!
    var resumableSub: PPResumableSubscription? = nil

    override func viewDidLoad() {
        super.viewDidLoad()


        app = App(
            id: "4ff02853-bfed-4590-80c7-40c09f25d113",
            client: PPBaseClient(
                cluster: "api.private-beta-1.pusherplatform.com",
                retryStrategyBuilder: { reqOpts in return PPDefaultRetryStrategy(maxNumberOfAttempts: 5) },
                heartbeatTimeoutInterval: 30,
                heartbeatInitialSize: 0
            )
        )

        let path = "feeds-service/feeds/resumable-ham/items"

        let requestOptions = PPRequestOptions(method: HTTPMethod.SUBSCRIBE.rawValue, path: path)

        let getOptions = PPRequestOptions(method: HTTPMethod.GET.rawValue, path: path)

        let retryableReq = app.requestWithRetry(
            using: getOptions,
            onSuccess: { data in print("SUCCESS: \(String(data: data, encoding: .utf8))") },
            onError: { error in print ("GENREQ ERRORED: \(error.localizedDescription)")}
        )

        resumableSub = PPResumableSubscription(app: app, requestOptions: requestOptions)

        app.subscribeWithResume(
            with: &resumableSub!,
            using: requestOptions,
            onOpening: { print("OPENING") },
            onOpen: { print("OPEN") },
            onResuming: { print("RESUMING") },
            onEvent: { eventId, headers, data in print("EVENT RECEIVED: \(data)") },
            onEnd: { statusCode, headers, error in print("ERROR RECEIVED: \(String(describing: statusCode)), \(String(describing: error))") },
            onError: { error in print ("SUB ERRORED: \(error.localizedDescription)")}
        )
    }
}
