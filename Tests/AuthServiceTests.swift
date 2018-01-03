import UIKit
import XCTest
import UptakeAuth
import UptakeNetworking
import Perfidy


class AuthServiceTests: XCTestCase {
  func testGetAuthenticationURLRequest() {
    let expectedParams = expectation(description: "waiting for request params")
    let expectedResponse = expectation(description: "waiting for response")
    
    enum K {
      static let callback = URL(string: "http://callback.example")!
      static let apiKey = "apiKey"
      static let clientID = "clientID"
      static let scope = "scope"
      static let provider = ProviderType.cws
    }
    
    let delegate = MockDelegate()
    let subject = AuthService(environment: .local, apiKey: K.apiKey, delegate: delegate)
    
    FakeServer.runWith { server in
      server.add("GET /authenticate_url") { req in
        XCTAssertEqual(req.allHTTPHeaderFields?["X-Api-Key"], K.apiKey)
        
        let params = URLComponents(url: req.url!, resolvingAgainstBaseURL: false)!.queryItems!
        XCTAssert(params.contains { $0.name == "clientId" && $0.value == K.clientID })
        XCTAssert(params.contains { $0.name == "callbackUri" && $0.value == K.callback.absoluteString })
        XCTAssert(params.contains { $0.name == "scope" && $0.value == K.scope })
        XCTAssert(params.contains { $0.name == "connection" && $0.value == K.provider.rawValue })
        
        expectedParams.fulfill()
      }
      subject.getAuthenticationURL(provider: K.provider, clientID: K.clientID, callback: K.callback, scope: K.scope) { _ in
        expectedResponse.fulfill()
      }
      
      wait(for: [expectedParams, expectedResponse], timeout: 1)
    }
  }
  
  
  func testGetAuthenticationURLResponse() {
    let expectedURL = expectation(description: "waiting for URL")
    let auth = URL(string: "http://auth.example")!
    
    let delegate = MockDelegate()
    let subject = AuthService(environment: .local, apiKey: "", delegate: delegate)

    FakeServer.runWith { server in
        server.add("GET /authenticate_url", response: try! Response(rawJSON: "\"\(auth.absoluteString)\""))
      subject.getAuthenticationURL(provider: .cws, clientID: "", callback: URL(string:"foo")!, scope: "") {
        if case .success(let url) = $0 {
          XCTAssertEqual(url, auth)
          expectedURL.fulfill()
        }
      }
      
      wait(for: [expectedURL], timeout: 1)
    }
  }
  
  
  func testGetAuthenticationURLServiceFailure() {
    let expectedFailure = expectation(description: "waiting for a failed result")
    
    let delegate = MockDelegate()
    let subject = AuthService(environment: .local, apiKey: "", delegate: delegate)
    
    FakeServer.runWith { server in
      server.add("GET /authenticate_url", response: 500)
      subject.getAuthenticationURL(provider: .cws, clientID: "", callback: URL(string:"foo")!, scope: "") {
        if case .failure(HTTPError.unexpectedStatus) = $0 {
          expectedFailure.fulfill()
        }
      }
      
      wait(for: [expectedFailure], timeout: 1)
    }
  }
  
  
  func testInvalidCallback() {
    let expectedFailure = expectation(description: "waiting for callback failure")
    
    let delegate = MockDelegate()
    delegate.failureExpectation = expectedFailure
    let service = AuthService(environment: .local, apiKey: "", delegate: delegate)
    service.processAuth0Callback(url: URL(string: "invalid")!)
    
    waitForExpectations(timeout: 1) { _ in
      guard case AuthError.invalidCallbackPayload? = delegate.failedWithError else {
        fatalError("Unexpected error: \(String(describing: delegate.failedWithError))")
      }
    }
  }
  
  
  func testValidCallback() {
    let expectedCallback = expectation(description: "waiting for callback delegate")
    
    let delegate = MockDelegate()
    delegate.callbackExpectation = expectedCallback
    let service = AuthService(environment: .local, apiKey: "", delegate: delegate)
    service.processAuth0Callback(url: URL(string: "scheme://example/callback#access_token=token&expires_in=42&scope=ascope")!)
    
    wait(for: [expectedCallback], timeout: 1)
  }
  
  
  func testGetTokenRequest() {
    let expectedParams = expectation(description: "waiting for request params")

    enum K {
      static let apiKey = "apiKey"
      static let token = "token"
    }
    
    let delegate = MockDelegate()
    let service = AuthService(environment: .local, apiKey: K.apiKey, delegate: delegate)
    
    FakeServer.runWith { server in
      server.add("GET /token") { req in
        XCTAssertEqual(req.allHTTPHeaderFields?["X-Api-Key"], K.apiKey)
        XCTAssertEqual(req.allHTTPHeaderFields?["Authorization"], K.token)
        expectedParams.fulfill()
      }
      
      service.processAuth0Callback(url: URL(string: "scheme://example/callback#access_token=\(K.token)&expires_in=42&scope=ascope")!)
      wait(for: [expectedParams], timeout: 1)
    }
  }
  
  
  func testGetTokenResponse() {
    let expectedToken = expectation(description: "waiting for token via delegate")
    let token: [String: Any] = [
      "access_token": "token",
      "expires_in": 42,
      "token_type": "Bearer"
    ]
    
    let delegate = MockDelegate()
    delegate.tokenExpectation = expectedToken
    let service = AuthService(environment: .local, apiKey: "", delegate: delegate)
    
    FakeServer.runWith { server in
      server.add("GET /token", response: try! Response(jsonObject: token))
      service.processAuth0Callback(url: URL(string: "scheme://example/callback#access_token=foo&expires_in=42&scope=ascope")!)
      waitForExpectations(timeout: 1) { _ in
        let serviceToken = delegate.resolvedAccessToken!
        XCTAssertEqual(serviceToken.accessToken, token["access_token"] as? String)
        XCTAssertEqual(serviceToken.expiresIn, Double(token["expires_in"] as! Int))
        XCTAssertEqual(serviceToken.type, token["token_type"] as? String)
      }
    }
  }


  func testGetTokenServiceFailure() {
    let expectedFailure = expectation(description: "waiting for failing delegate call")
    
    let delegate = MockDelegate()
    delegate.failureExpectation = expectedFailure
    let service = AuthService(environment: .local, apiKey: "", delegate: delegate)
    
    FakeServer.runWith { server in
      server.add("GET /token", response: Response(status: 500, data: nil))
      service.processAuth0Callback(url: URL(string: "scheme://example/callback#access_token=foo&expires_in=42&scope=ascope")!)
      
      waitForExpectations(timeout: 1) { _ in
        guard case UptakeNetworking.HTTPError.unexpectedStatus? = delegate.failedWithError else {
          fatalError("Unexpected error: \(String(describing: delegate.failedWithError))")
        }
      }
    }
  }
  
  
  func testGetTokenConnectionFailure() {
    let expectedFailure = expectation(description: "waiting for failing delegate call")
    
    let delegate = MockDelegate()
    delegate.failureExpectation = expectedFailure
    let service = AuthService(environment: .local, apiKey: "", delegate: delegate)
    
    service.processAuth0Callback(url: URL(string: "scheme://example/callback#access_token=foo&expires_in=42&scope=ascope")!)
    
    waitForExpectations(timeout: 1) { _ in
      guard case URLError.cannotConnectToHost? = delegate.failedWithError else {
        fatalError("Unexpected error: \(String(describing: delegate.failedWithError))")
      }
    }
  }

  
  func testGetTokenBadResponse() {
    let expectedFailure = expectation(description: "waiting for failing delegate call")
    
    let delegate = MockDelegate()
    delegate.failureExpectation = expectedFailure
    let service = AuthService(environment: .local, apiKey: "", delegate: delegate)
    
    FakeServer.runWith { server in
      server.add("GET /token", response: "foo")
      service.processAuth0Callback(url: URL(string: "scheme://example/callback#access_token=foo&expires_in=42&scope=ascope")!)
      
      waitForExpectations(timeout: 1) { _ in
        guard case ResponseError.unexpectedBody? = delegate.failedWithError else {
          fatalError("Unexpected error")
        }
      }
    }
  }
}
