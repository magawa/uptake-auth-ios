import Foundation
import UptakeToolbox
import UptakeNetworking



/// Defines the methods a conforming delegate of `AuthService` will receive.
public protocol AuthServiceDelegate: class {
  /// Called when the `authService` has received and successfully parsed the callback URL from the client.
  func authServiceReceivedAuth0Callback(_ authService: AuthService)
  
  /// Called when `authService` has successfully procured an access token from the given service.
  func authService(_ authService: AuthService, resolvedAccessToken accessToken: UptakeSSOToken)
  
  /** 
   Called in the event of an error in `authService`.
   
   Possible errors:
   
   - `AuthError.invalidAuth0TokenPayload` — when there's an problem decoding params from the auth URL.
   
   - `HTTPError.unexpectedStatusCode` — when there's an unexpected status code.
   
   - `ResponseError.unexpectedBody` — for problems with content or format of the returned JSON.
   
   - All the errors from `UptakeNetworking`.
   */
  func authService(_ authService: AuthService, failedWithError error: Error)
}


/// Primary class of the authentication framework. See `README.md` for usage.
public class AuthService {
  fileprivate weak var delegate: AuthServiceDelegate?
  fileprivate let uptakeHost: Host
  
  
  /**
   Initializes a new instance of the authentication service. 
   
   - Parameter environment: The environment (production, staging, &c.) to use for authentication. This primarily effects what servers auth API calls are sent to.
   
   - Parameter apiKey: The API key, as used in the "X-Api-Key" header.
   
   - Parameter delegate: An `AuthServiceDelegate`-conforming delegate object.
   */
  public init(environment: AuthEnvironment, apiKey: String, delegate: AuthServiceDelegate) {
    self.delegate = delegate
    
    let url: URL
    switch(environment) {
    case .dev:
      url = URL(string: "http://auth.services.symphony.dev.uptake.com/v1")!
    case .staging:
      url = URL(string: "https://uptake-prod-staging.apigee.net/cat/auth/v1")!
    case .production:
      url = URL(string: "https://uptake-prod-production.apigee.net/cat/auth/v1")!
    case .qa:
      url = URL(string: "https://auth.services.qa2.qa.uptake.com/v1")!

    case .local:
      url = URL(string: "http://localhost:10175")!
    }

    debug?{[
      "INIT-------------",
      "URL: \(url.absoluteString)",
      "API Key: \(apiKey)",
      ]}
    
    uptakeHost = Host(url: url, constantHeaders: [.custom("X-Api-Key"): apiKey])
  }
}



public extension AuthService {
  /**
   Get the URL of a configured service's SSO page from the Uptake Auth Service. User's should be directed to this page
   
   - Parameter provider: The SSO service's corresponding ProviderType

   - Parameter clientID: The SSO service's configured Client ID/Key, must match the value provied by SSO service

   - Parameter callback: The SSO service's callbackURI, must match the value defined in SSO service configuration

   - Parameter scope: A value passed to request user and profile infromation along with the access token. See: [Auth0 Scopes](https://auth0.com/docs/scopes)

   - Parameter completion: A closure that will either return the sign-in URL or an error

   - Parameter result: A `Result` type holding either the fetched URL, or an error.
   
     Possible errors:
     
     - `URLSessionDataTask`, `ResponseError`, `HTTPError` from `UptakeNetworking`.
     
     - `HTTPError.unexpectedStatus` — Auth API responded with non-2xx code.
     
     - `ResponseError.unexpectedBody` — Auth API responded with a body that's not a URL string.
   */
  func getAuthenticationURL(provider: ProviderType, clientID: String, callback: URL, scope: String, completion: @escaping (_ result: Result<URL>) -> Void) {
    
    debug? {[
      "GET AUTH URL--------------",
      "Provider: \(provider.rawValue)",
      "Scope: \(scope)",
      "Callback URI: \(callback)",
      "Client ID: \(clientID)",
      ]}
    
    let params = [
      URLQueryItem(name: "clientId", value: clientID),
      URLQueryItem(name: "callbackUri", value: String(describing: callback)),
      URLQueryItem(name: "scope", value: scope),
      URLQueryItem(name: "connection", value: provider.rawValue)
    ]
    uptakeHost.get("/authenticate_url", params: params) {
      completion($0.flatMap { statusCode, anyJSON in
        guard case HTTPStatusCode.successRange = statusCode else {
          return .failure(HTTPError.unexpectedStatus(statusCode))
        }
        guard
          case .string(let _url)? = anyJSON,
          let url = URL(string: _url) else {
            return .failure(ResponseError.unexpectedBody)
        }
        return .success(url)
      })
    }
  }
  
  
  /**
   Process an Auth0 callback URL, asynchronously exchanging it for an auth token (which will then be delivered via the delegate).
   
   - Note: In iOS apps, callback URLs are usually obtained from AppDelegate's `application(_:open:options:)`. See `README.md` for more info.
   
   - Parameter url: The callback URL.
   */
  func processAuth0Callback(url: URL) {
    debug? {[
      "PROCESS CALLBACK------------",
      "Callback: \(url.absoluteString)",
      ]}

    guard let token = Auth0SSOToken(callbackURL: url) else {
      self.delegate?.authService(self, failedWithError: AuthError.invalidCallbackPayload)
      return
    }
    
    debug? {["Callback Token: \(token)"]}
    self.delegate?.authServiceReceivedAuth0Callback(self)
    
    uptakeHost.get("/token", headers: [.authorization: token.accessToken]) {
      switch $0 {
      case let .success(code, anyJSON):
        guard case HTTPStatusCode.successRange = code else {
          self.delegate?.authService(self, failedWithError: HTTPError.unexpectedStatus(code))
          return
        }
        
        guard case .object(let json)? = anyJSON else {
          self.delegate?.authService(self, failedWithError: ResponseError.unexpectedBody)
          return
        }
        
        guard let token = try? UptakeSSOToken(json: json) else {
          self.delegate?.authService(self, failedWithError: ResponseError.unexpectedBody)
          return
        }
        
        debug? {["Access Token: \(token)"]}
        self.delegate?.authService(self, resolvedAccessToken: token)

      case .failure(let e):
        self.delegate?.authService(self, failedWithError: e)
      }
    }
  }
}



private extension URL {
  func addQueryParameters(_ parameters: [String: String]) -> URL? {
    guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
      return nil
    }
    for (key, value) in parameters {
      components.queryItems?.append(URLQueryItem(name: key, value: value))
    }
    
    debug? {[
      "Appended params:\n\(parameters)",
      "New URL: \(components.url?.absoluteString ?? "nil")"
      ]}
    return components.url
  }
}

