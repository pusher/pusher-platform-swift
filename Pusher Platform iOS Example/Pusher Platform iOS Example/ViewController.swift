import UIKit
import PusherPlatform

class ViewController: UIViewController {

    var instance: Instance!
    var filesInstance: Instance!
    var resumableSub: PPResumableSubscription? = nil

    override func viewDidLoad() {
        super.viewDidLoad()

        let instanceLocator = "YOUR_INSTANCE_LOCATOR"

//        let localBaseClient = PPBaseClient(
//            host: "localhost",
//            port: 10444,
//            insecure: true,
//            heartbeatTimeoutInterval: 30
//        )

        let tokenProvider = PPHTTPEndpointTokenProvider(
            url: "YOUR_TOKEN_PROVIDER_URL"
//            requestInjector: { req -> PPHTTPEndpointTokenProviderRequest in
//                req.addQueryItems([URLQueryItem(name: "user_id", value: userId)])
//                return req
//            }
        )

        // Testing using Chatkit service

//        let userId = "ham"

        instance = Instance(
            locator: instanceLocator,
            serviceName: "chatkit",
            serviceVersion: "v1",
            tokenProvider: tokenProvider,
//            client: localBaseClient,
            logger: TestLogger()
        )

//        filesInstance = Instance(
//            locator: instanceLocator,
//            serviceName: "chatkit_files",
//            serviceVersion: "v1",
//            tokenProvider: tokenProvider,
////            client: localBaseClient,
//            logger: TestLogger()
//        )

//        let requestOptions = PPRequestOptions(method: HTTPMethod.SUBSCRIBE.rawValue, path: "/users")
//        resumableSub = PPResumableSubscription(instance: instance, requestOptions: requestOptions)
//
//        instance.subscribeWithResume(
//            with: &resumableSub!,
//            using: requestOptions,
//            onOpening: { print("OPENING") },
//            onOpen: { print("OPEN") },
//            onResuming: { print("RESUMING") },
//            onEvent: { eventId, headers, data in print("EVENT RECEIVED: \(data)") },
//            onEnd: { statusCode, headers, error in print("ERROR RECEIVED: \(String(describing: statusCode)), \(String(describing: error))") },
//            onError: { error in print ("SUB ERRORED: \(error.localizedDescription)")}
//        )

//        let reqOptions = PPRequestOptions(method: HTTPMethod.POST.rawValue, path: "/rooms/123/files/someimage.jpg")

//        filesInstance.upload(
//            using: reqOptions,
//            multipartFormData: { mfd in
//                let imageName = Bundle.main.path(forResource: "someimage", ofType: "jpg")
//                let imageURL = URL(fileURLWithPath: imageName!)
//                mfd.append(imageURL, withName: "file", fileName: "someimage.jpg")
//            },
//            onSuccess: { data in
//                print("Upload success!")
//
//                guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) else {
//                    return
//                }
//
//                guard let uploadResPayload = jsonObject as? [String: Any] else {
//                    return
//                }
//
//                print("uploadResPayload", uploadResPayload)
//
//                guard let resLink = uploadResPayload["resource_link"] as? String else {
//                    return
//                }
//
//                print("Success! \(resLink)")
//
//                let rawOptions = PPRequestOptions(method: HTTPMethod.GET.rawValue, destination: .absolute(resLink))
//
//                self.filesInstance.request(
//                    using: rawOptions,
//                    onSuccess: { data in
//                        guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) else {
//                            return
//                        }
//
//                        guard let attachmentPayload = jsonObject as? [String: Any] else {
//                            return
//                        }
//
//                        guard let link = attachmentPayload["resource_link"] as? String else {
//                            return
//                        }
//
//                        print("Success! \(link)")
//
//                        let downloadOptions = PPRequestOptions(method: HTTPMethod.GET.rawValue, destination: .absolute(link))
//                        let options: PPDownloadOptions = [.removePreviousFile, .createIntermediateDirectories]
//
//                        self.filesInstance.client.download(
//                            using: downloadOptions,
//                            to: PPSuggestedDownloadDestination(options: options),
//                            onSuccess: { data in
//                                print("Download success!")
//                            },
//                            onError: { err in
//                                print("Error: \(err.localizedDescription)")
//                            },
//                            progressHandler: { bytesWritten, totalBytesToWrite in
//                                print("Download \(Float(bytesWritten) / Float(totalBytesToWrite))% complete")
//                            }
//                        )
//                    },
//                    onError: { err in
//                        print("Error: \(err.localizedDescription)")
//                    }
//                )
//            },
//            onError: { err in
//                print("Error: \(err.localizedDescription)")
//            },
//            progressHandler: { bytesSent, totalBytesToSend in
//                print("Upload \(Float(bytesSent) / Float(totalBytesToSend))% complete")
//            }
//        )
    }
}


public struct TestLogger: PPLogger {
    public func log(_ message: @autoclosure @escaping () -> String, logLevel: PPLogLevel) {
        print("TestLogger: \(message())")
    }
}
