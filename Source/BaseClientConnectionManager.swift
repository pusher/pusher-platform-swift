//
//  BaseClientConnectionManager.swift
//  ElementsSwift
//
//  Created by Hamilton Chapman on 26/10/2016.
//
//

import Foundation

// TODO: not sure if this is the best abstaction - do we even want a separate "manager" object?
@objc public class ConnectionManager: NSObject {
    public var subscriptions: [Int: Subscription] = [:]

    // public init() {}
}
