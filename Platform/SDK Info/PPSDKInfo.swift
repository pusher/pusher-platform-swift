import Foundation

public struct PPSDKInfo {
    let productName: String
    let sdkVersion: String
    let sdkLanguage: String = "swift"
    let platform: String

    let headers: [String: String]

    private init(productName: String, sdkVersion: String, platform: String) {
        self.productName = productName
        self.sdkVersion = sdkVersion
        self.platform = platform

        self.headers = [
            "X-SDK-Product": self.productName,
            "X-SDK-Version": self.sdkVersion,
            "X-SDK-Language": self.sdkLanguage,
            "X-SDK-Platform": self.platform
        ]
    }

    #if os(macOS)
    public init(productName: String, sdkVersion: String) {
        self.init(productName: productName, sdkVersion: sdkVersion, platform: "macOS")
    }
    #elseif os(iOS)
    public init(productName: String, sdkVersion: String) {
        self.init(productName: productName, sdkVersion: sdkVersion, platform: "iOS")
    }
    #elseif os(tvOS)
    public init(productName: String, sdkVersion: String) {
        self.init(productName: productName, sdkVersion: sdkVersion, platform: "tvOS")
    }
    #elseif os(watchOS)
    public init(productName: String, sdkVersion: String) {
        self.init(productName: productName, sdkVersion: sdkVersion, platform: "watchOS")
    }
    #elseif os(Linux)
    public init(productName: String, sdkVersion: String) {
        self.init(productName: productName, sdkVersion: sdkVersion, platform: "Linux")
    }
    #else
    public init(productName: String, sdkVersion: String, platform: String) {
        self.init(productName: productName, sdkVersion: sdkVersion, platform: platform)
    }
    #endif
}
