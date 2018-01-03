import Foundation
import Medea



/// A structure modeling an access token for Uptake web services.
public struct UptakeSSOToken {
  
  
  /// Initialization errors.
  public enum Initialization: LocalizedError {
    /// The JSON payload did not contain the expected fields.
    case jsonMismatch
    
    public var errorDescription: String? {
      switch self {
      case .jsonMismatch:
        return "Unable to initialize Uptake Token with given data."
      }
    }
  }
  
  
  /// The access token.
  public let accessToken: String
  
  /// Expiry time.
  public let expiresIn: TimeInterval?
  
  /// Token type.
  public let type: String?
  
  
  /// Memberwise initializer.
  public init(accessToken: String, expiresIn: TimeInterval? = nil, type: String? = nil) {
    self.accessToken = accessToken
    self.expiresIn = expiresIn
    self.type = type
  }
  
  
  /**
   Initializes the receiver with the given JSON object. Throws on error, though the particular circumstance of the error is often uninteresting.
   
   - Parameter json: A JSON object presumably representing a token. Expected to have "access_token", "expires_in", and "token_type" fields.

   - Throws: `UptakeSSOToken.Initialization` errors.
   */
  public init(json: JSONObject) throws {
    guard let accessToken = json["access_token"] as? String else {
        throw Initialization.jsonMismatch
    }
    let expiresIn = json["expires_in"] as? TimeInterval
    let tokenType = json["token_type"] as? String
    self.init(accessToken: accessToken, expiresIn: expiresIn, type: tokenType)
  }
}
