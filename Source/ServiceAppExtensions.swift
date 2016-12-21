import Foundation

extension App {

    public func feeds(_ name: String) -> FeedsHelper {
        return FeedsHelper(name, app: self)
    }

}
