//
//  ServiceHelper.swift
//  ElementsSwift
//
//  Created by Hamilton Chapman on 05/10/2016.
//
//

@objc public protocol ServiceHelper: class {
    var app: ElementsApp? { get set }
    static var namespace: String { get }
}

public enum ServiceHelperError: Error {
    case noAppObject
    case invalidJSONObjectAsData(Any)
    case failedToJSONSerializeData(Any)
}
