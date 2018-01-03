import Foundation



/// Errors used within the scope of AuthService
public enum AuthError: LocalizedError {
  /// Thrown if a callback URL cannot be deserialized or is otherwise malformed
  case invalidCallbackPayload
  
  public var errorDescription: String? {
    switch self {
    case .invalidCallbackPayload:
      return "The callback URL cannot be parsed."
    }
  }
}

