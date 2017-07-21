import UIKit
import PusherPlatform

class ViewController: UIViewController {

    var instance: Instance!
    var resumableSub: PPResumableSubscription? = nil

    override func viewDidLoad() {
        super.viewDidLoad()

        let userId = "will"
        let serviceId = "some-instance-id"
        let path = "/chatkit/v1/users"

        let localBaseClient = PPBaseClient(
            cluster: "localhost",
            port: 10443,
            insecure: true,
            heartbeatTimeoutInterval: 30
        )

        let kubeBaseClient = PPBaseClient(
            cluster: "api-ceres.pusherplatform.io",
            insecure: true
        )

        let tokenProvider = PPHTTPEndpointTokenProvider(
            url: "https://chat-api-test-token-provider.herokuapp.com/token",
            requestInjector: { req -> PPHTTPEndpointTokenProviderRequest in
                req.addQueryItems(
                    [
                        URLQueryItem(name: "user_id", value: userId),
                        URLQueryItem(name: "service_id", value: serviceId)
                    ]
                )
                return req
            }
        )

        instance = Instance(
            id: serviceId,
            tokenProvider: tokenProvider,
            client: localBaseClient,
            logger: HamLogger()
        )

        let requestOptions = PPRequestOptions(method: HTTPMethod.SUBSCRIBE.rawValue, path: path)

        resumableSub = PPResumableSubscription(instance: instance, requestOptions: requestOptions)

        instance.subscribeWithResume(
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


public struct HamLogger: PPLogger {
    public func log(_ message: @autoclosure @escaping () -> String, logLevel: PPLogLevel) {
        print("HAMLOG: \(message())")
    }
}
