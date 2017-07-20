final class ClientVersion {
    class func shortVersion() -> String {
        let bundle = Bundle(identifier: "com.pusher.PusherPlatform")!
        let shortVersion = bundle.infoDictionary?["CFBundleShortVersionString"] as? String

        return shortVersion!
    }
}
