//
//  HttpAuthorizer.swift
//  ElementsSwift
//
//  Created by Hamilton Chapman on 05/10/2016.
//
//

@objc public class HttpAuthorizer: NSObject, Authorizer {
    public var url: String

    public init(url: String) {
        self.url = url
    }

    public func authorize() -> Token {
        // TODO: fix this
        return Token(
            appId: "TODO: FIX THIS APPID",
            key: "TODO: FIX THIS KEY",
            jwt: "TODO: FIX ME",
            grants: nil,
            userId: nil
        )
    }
}
