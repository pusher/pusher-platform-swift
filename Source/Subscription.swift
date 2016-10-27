//
//  Subscription.swift
//  ElementsSwift
//
//  Created by Hamilton Chapman on 26/10/2016.
//
//

import Foundation

@objc public class Subscription: NSObject {
    public var path: String
    public var taskIdentifier: Int
    public var onOpen: (() -> Void)? = nil
    public var onEnd: ((Int, String) -> Void)? = nil
    public var onEvent: ((Data) -> Void)? = nil

    public init(path: String, taskIdentifier: Int) {
        self.path = path
        self.taskIdentifier = taskIdentifier
    }
}
