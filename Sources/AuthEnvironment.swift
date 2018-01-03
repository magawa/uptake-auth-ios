import Foundation



/// The environment with which to authenticate.
public enum AuthEnvironment: String {
  /// Staging environment.
  case staging
  
  /// Development environment.
  case dev
  
  /// Production/deployment environment.
  case production
  
  /// Quality assurance environment.
  case qa

  /// Internal testing environment.
  case local
}
