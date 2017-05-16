import Foundation

// Code based on SwiftHTTP https://github.com/daltoniam/SwiftHTTP
// License: Apache-2.0
// Modifications made for usage in pusher-platform-swift

/**
    This protocol is used to make the dictionary and array serializable into key/value pairs.
*/
public protocol HTTPParameterProtocol {
    func createPairs(_ key: String?) -> Array<HTTPPair>
}

/**
    Support for the Dictionary type as an HTTPParameter.
*/
extension Dictionary: HTTPParameterProtocol {
    public func createPairs(_ key: String?) -> Array<HTTPPair> {
        var collect: [HTTPPair] = []

        for (k, v) in self {
            if let nestedKey = k as? String {
                let useKey = key != nil ? "\(key!)[\(nestedKey)]" : nestedKey
                if let subParam = v as? HTTPParameterProtocol {
                    collect.append(contentsOf: subParam.createPairs(useKey))
                } else if let subParam = v as? Array<AnyObject> {
                    //                    // TODO: Maybe works??
                    //                    collect.append(contentsOf: subParam.createPairs(useKey))
                    for s in subParam.createPairs(useKey) {
                        collect.append(s)
                    }
                } else {
                    collect.append(HTTPPair(key: useKey, value: v as AnyObject))
                }
            }
        }

        return collect
    }
}

/**
    Support for the Array type as an HTTPParameter.
*/
extension Array: HTTPParameterProtocol {
    public func createPairs(_ key: String?) -> Array<HTTPPair> {
        var collect = Array<HTTPPair>()
        for v in self {
            let useKey = key != nil ? "\(key!)[]" : key
            if let subParam = v as? Dictionary<String, AnyObject> {
                collect.append(contentsOf: subParam.createPairs(useKey))
            } else if let subParam = v as? Array<AnyObject> {
                //collect.appendContentsOf(subParam.createPairs(useKey)) <- bug? should work.
                for s in subParam.createPairs(useKey) {
                    collect.append(s)
                }
            } else {
                collect.append(HTTPPair(key: useKey, value: v as AnyObject))
            }
        }
        return collect
    }
}

/**
    This is used to create key/value pairs of the parameters
*/
public struct HTTPPair {
    var key: String?
    let storeVal: AnyObject

    /**
        Create the object with a possible key and a value
    */
    init(key: String?, value: AnyObject) {
        self.key = key
        self.storeVal = value
    }

    /**
        Computed property of the string representation of the storedVal
    */
    var value: String {
        if let v = storeVal as? String {
            return v
        } else if let v = storeVal.description {
            return v
        }
        return ""
    }

    /**
        Computed property of the string representation of the storedVal escaped for URLs
    */
    var escapedValue: String {
        let allowedCharacterSet = CharacterSet(charactersIn: "!*'();:@&=+$,/?%#[]. ").inverted

        if let v = value.addingPercentEncoding(withAllowedCharacters: allowedCharacterSet) {
            if let k = key {
                if let escapedKey = k.addingPercentEncoding(withAllowedCharacters: allowedCharacterSet) {
                    return "\(escapedKey)=\(v)"
                }
            }
            return v
        }
        return ""
    }
}
