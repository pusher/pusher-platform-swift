import UIKit
import PusherPlatform

class ViewController: UIViewController {

    var app: App!
    var resumableSub: ResumableSubscription? = nil

    override func viewDidLoad() {
        super.viewDidLoad()


        app = App(id: "4ff02853-bfed-4590-80c7-40c09f25d113", cluster: "api.private-beta-1.pusherplatform.com")

        let path = "feeds-service/feeds/resumable-ham/items"
        let subscribeRequest = SubscribeRequest(path: path)

        resumableSub = ResumableSubscription(app: app, request: subscribeRequest)

        app.subscribeWithResume(
            with: &resumableSub!,
            using: subscribeRequest,
            onOpening: { print("OPENING") },
            onOpen: { print("OPEN") },
            onResuming: { print("RESUMING") },
            onEvent: { eventId, headers, data in print("EVENT RECEIVED: \(data)") },
            onEnd: { statusCode, headers, error in print("ERROR RECEIVED: \(statusCode), \(error)") },
            onError: { error in print ("ERRORED: \(error)")}
        )
    }
}
