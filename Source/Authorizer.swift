//
//  Authorizer.swift
//  ElementsSwift
//
//  Created by Hamilton Chapman on 05/10/2016.
//
//

import PromiseKit

public protocol Authorizer {
    func authorize() -> Promise<String>
}
