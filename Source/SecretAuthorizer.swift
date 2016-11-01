//
//  SecretAuthorizer.swift
//  ElementsSwift
//
//  Created by Hamilton Chapman on 05/10/2016.
//
//

import JWT
import PromiseKit

@objc public class SecretAuthorizer: NSObject, Authorizer {
    public var appId: String
    public var secret: String
    public var grants: [String: [String]]?
    public var userId: String?

    public init(appId: String, secret: String, grants: [String: [String]]? = nil, userId: String? = nil) {
        self.appId = appId
        self.secret = secret
        self.grants = grants
        self.userId = userId
    }

    public func getToken(grants: [String: [String]]? = nil, userId: String? = nil) -> String {
        let grantsForJwt = grants ?? self.grants ?? nil
        let userIdForJwt = userId ?? self.userId ?? nil

        // TODO: Make this work with format secret:$KEY:$SECRET
        let key = secret.components(separatedBy: ":").first
        let secretOfSecret = secret.components(separatedBy: ":").last

        let algorithm = Algorithm.hs256(secretOfSecret!.data(using: .utf8)!)

        let jwt = JWT.encode(algorithm) { builder in
            builder.audience = self.appId

            if key != nil {
                builder.issuer = key
            }

            // TODO: can't use this at the moment as issuedAt here is not an Int, which is currently required by the bridge
            // builder.issuedAt = Date()

            if userIdForJwt != nil {
                builder["sub"] = self.userId!
            }

            if grantsForJwt != nil {
                builder["grants"] = self.grants!
            }
        }

        print(jwt)

        return jwt
    }

    public func authorize() -> Promise<String> {
        return Promise { resolve, reject in
            resolve(getToken())
        }
    }
}
