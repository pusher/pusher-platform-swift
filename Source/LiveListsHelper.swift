//
//  ElementsLiveListsHelper.swift
//  ElementsSwift
//
//  Created by Hamilton Chapman on 05/10/2016.
//
//

@objc public class LiveListsHelper: NSObject, ServiceHelper {
    public var app: ElementsApp

    public init(app: ElementsApp) {
        self.app = app
    }
}
