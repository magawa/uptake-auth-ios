import Foundation



internal struct Auth0SSOToken {
  let accessToken: String
  let expiresIn: TimeInterval?
  let scope: String?
  
  
  init(accessToken: String, expiresIn: TimeInterval? = nil, scope: String? = nil) {
    self.accessToken = accessToken
    self.expiresIn = expiresIn
    self.scope = scope
  }
  
  
  init?(callbackURL: URL) {
    let urlString = callbackURL.absoluteString.replacingOccurrences(of: "callback#", with: "callback?")
    
    guard
      let _urlComponents = URLComponents(string: urlString),
      let queryItems = _urlComponents.queryItems else {
        return nil
    }
    
    guard let accessToken = queryItems.first(where: { $0.name == "access_token" })?.value else {
        return nil
    }
    
    let scope = queryItems.first(where: { $0.name == "scope" })?.value
    
    var expiresIn: TimeInterval?
    if let expiresString = queryItems.first(where: { $0.name == "expires_in" })?.value {
      expiresIn = TimeInterval(expiresString)
    }
    
    self.init(accessToken: accessToken, expiresIn: expiresIn, scope: scope)
  }
}



