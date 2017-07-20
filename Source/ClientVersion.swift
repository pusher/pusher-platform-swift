final class ClientVersion {
    class func shortVersion() -> String {
        let bundle = Bundle(identifier: "com.pusher.PusherPlatform")!
        return bundle.infoDictionary!["CFBundleShortVersionString"] as! String
    }
}
