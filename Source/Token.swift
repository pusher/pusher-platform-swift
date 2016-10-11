//
//  Token.swift
//  ElementsSwift
//
//  Created by Hamilton Chapman on 05/10/2016.
//
//

@objc public class Token: NSObject {
    public var appId: String
    public var key: String
    public var jwt: String
    public var grants: [String: [String]]?
    public var userId: String?

    public init(appId: String, key: String, jwt: String, grants: [String: [String]]? = nil, userId: String? = nil) {
        self.appId = appId
        self.key = key
        self.jwt = jwt
        self.grants = grants
        self.userId = userId
    }
}
