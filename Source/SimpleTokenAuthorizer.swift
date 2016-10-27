//
//  SimpleTokenAuthorizer.swift
//  ElementsSwift
//
//  Created by Hamilton Chapman on 26/10/2016.
//
//

import Foundation
import JWT
import PromiseKit

@objc public class SimpleTokenAuthorizer: NSObject, Authorizer {
    public var jwt: String

    public init(jwt: String) {
        self.jwt = jwt
    }

    public func authorize() -> Promise<String> {
        return Promise { resolve, reject in
            resolve(self.jwt)
        }
    }
}
