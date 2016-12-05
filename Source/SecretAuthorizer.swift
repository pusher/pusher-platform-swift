import JWT
import PromiseKit

@objc public class SecretAuthorizer: NSObject, Authorizer {
    public var appId: String
    public var grants: [String: [String]]?
    public var userId: String?

    public let secret: String
    public let key: String

    public init(appId: String, secret: String, grants: [String: [String]]? = nil, userId: String? = nil) throws {
        let secretComponents = secret.components(separatedBy: ":")
        let secretPrefix = secretComponents.first

        guard secretComponents.count == 3, secretPrefix != nil, secretPrefix! == "secret" else {
            throw SecretAuthorizerError.invalidSecret(secret)
        }

        self.secret = secretComponents.last!
        self.key = secretComponents[1]

        self.appId = appId
        self.grants = grants
        self.userId = userId
    }

    public func getToken(grants: [String: [String]]? = nil, userId: String? = nil) -> String {
        let grantsForJwt = grants ?? self.grants ?? nil
        let userIdForJwt = userId ?? self.userId ?? nil

        let algorithm = Algorithm.hs256(self.secret.data(using: .utf8)!)

        let jwt = JWT.encode(algorithm) { builder in
            builder.audience = self.appId
            builder.issuer = self.key

            // TODO: can't use issuedAt at the moment as issuedAt here is not an Int
            // which is currently required by the bridge

            // builder.issuedAt = Date()

            if userIdForJwt != nil {
                builder["sub"] = self.userId!
            }

            if grantsForJwt != nil {
                builder["grants"] = self.grants!
            }
        }

        return jwt
    }

    public func authorize() -> Promise<String> {
        return Promise { resolve, reject in
            resolve(getToken())
        }
    }
}

public enum SecretAuthorizerError: Error {
    case invalidSecret(String)
}
