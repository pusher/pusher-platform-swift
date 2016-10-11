//
//  ApiKey.swift
//  ElementsSwift
//
//  Created by Hamilton Chapman on 05/10/2016.
//
//

import JWT

@objc public class ApiKey: NSObject, Authorizer {
    public var appId: String
    public var key: String
    public var secret: String
    public var grants: [String: [String]]?
    public var userId: String?

    public init(appId: String, key: String, secret: String, grants: [String: [String]]? = nil, userId: String? = nil) {
        self.appId = appId
        self.key = key
        self.secret = secret
        self.grants = grants
        self.userId = userId
    }

    public func getToken(grants: [String: [String]]? = nil, userId: String? = nil) -> Token {
        let grants = grants ?? self.grants ?? nil
        let userId = userId ?? self.userId ?? nil

        let algorithm = Algorithm.hs256(self.secret.data(using: .utf8)!)

        let jwt = JWT.encode(algorithm) { builder in
            builder.audience = self.appId
            builder.issuer = self.key
            // TODO: can't use this at the moment as issuedAt here is not an Int, which is currently required by the bridge
            // builder.issuedAt = Date()

            if self.userId != nil {
                builder["sub"] = self.userId!
            }

            if self.grants != nil {
                builder["grants"] = self.grants!
            }
        }

        return Token(
            appId: self.appId,
            key: self.key,
            jwt: jwt,
            grants: grants,
            userId: userId
        )
    }

    public func authorize() -> Token {
        return getToken()
    }
}

// TODO: remove this
@objc public class TokenOpt℩ons: NSObject {
    public let grants: [[String: [String]]]?
    public let userId: String?

    public init(grants: [[String: [String]]]? = nil, userId: String? = nil) {
        self.grants = grants
        self.userId = userId
    }
}
