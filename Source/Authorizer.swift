//
//  Authorizer.swift
//  ElementsSwift
//
//  Created by Hamilton Chapman on 05/10/2016.
//
//

@objc public protocol Authorizer: class {
    func authorize() -> Token
}
