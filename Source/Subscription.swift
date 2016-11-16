//
//  Subscription.swift
//  ElementsSwift
//
//  Created by Hamilton Chapman on 26/10/2016.
//
//

import Foundation

@objc public class Subscription: NSObject {
    public let path: String
    public let taskIdentifier: Int

    public var onOpen: (() -> Void)? = nil
    public var onEnd: ((Int, [String: String], Any) -> Void)? = nil
    public var onEvent: ((String, [String: String], Any) -> Void)? = nil

    public init(path: String, taskIdentifier: Int) {
        self.path = path
        self.taskIdentifier = taskIdentifier
    }
}
