//
//  ServiceAppExtensions.swift
//  ElementsSwift
//
//  Created by Hamilton Chapman on 25/11/2016.
//
//

import Foundation

extension ElementsApp {
 
    public func feeds(feedName: String) -> FeedsHelper {
        return FeedsHelper(feedName: feedName, app: self)
    }
    
}
