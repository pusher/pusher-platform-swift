import Foundation

extension App {

    public func feed(_ name: String) -> Feed {
        return Feed(name, app: self)
    }

}
