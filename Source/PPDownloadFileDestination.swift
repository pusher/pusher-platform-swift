//
//  Copyright (c) 2014-2017 Alamofire Software Foundation (http://alamofire.org/)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//
// This has been slightly adapted from Alamofire for use in this SDK

import Foundation

/// A collection of options to be executed prior to moving a downloaded file from the temporary URL to the
/// destination URL.
public struct PPDownloadOptions: OptionSet {
    /// Returns the raw bitmask value of the option and satisfies the `RawRepresentable` protocol.
    public let rawValue: UInt

    /// A `DownloadOptions` flag that creates intermediate directories for the destination URL if specified.
    public static let createIntermediateDirectories = PPDownloadOptions(rawValue: 1 << 0)

    /// A `DownloadOptions` flag that removes a previous file from the destination URL if specified.
    public static let removePreviousFile = PPDownloadOptions(rawValue: 1 << 1)

    /// Creates a `DownloadFileDestinationOptions` instance with the specified raw value.
    ///
    /// - parameter rawValue: The raw bitmask value for the option.
    ///
    /// - returns: A new log level instance.
    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }
}

/// A closure executed once a download request has successfully completed in order to determine where to move the
/// temporary file written to during the download process. The closure takes two arguments: the temporary file URL
/// and the URL response, and returns a two arguments: the file URL where the temporary file should be moved and
/// the options defining how the file should be moved.
public typealias PPDownloadFileDestination = (_ temporaryURL: URL, _ response: HTTPURLResponse) -> (destinationURL: URL, options: PPDownloadOptions)

public func PPSuggestedDownloadDestination(
    for directory: FileManager.SearchPathDirectory = .documentDirectory,
    in domain: FileManager.SearchPathDomainMask = .userDomainMask,
    options: PPDownloadOptions = []
) -> PPDownloadFileDestination {
    return { temporaryURL, response in
        let directoryURLs = FileManager.default.urls(for: directory, in: domain)

        if !directoryURLs.isEmpty {
            return (directoryURLs[0].appendingPathComponent(response.suggestedFilename!), options)
        }

        return (temporaryURL, options)
    }
}
