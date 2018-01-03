import Foundation
import XCTest
import UptakeAuth


internal class MockDelegate: AuthServiceDelegate {
  var receivedAuth0Callback: Bool = false
  var resolvedAccessToken: UptakeSSOToken?
  var failedWithError: Error?
  
  var callbackExpectation: XCTestExpectation?
  var tokenExpectation: XCTestExpectation?
  var failureExpectation: XCTestExpectation?
  
  
  func authServiceReceivedAuth0Callback(_ authService: AuthService) {
    receivedAuth0Callback = true
    callbackExpectation?.fulfill()
  }
  
  
  func authService(_ authService: AuthService, failedWithError error: Error) {
    failedWithError = error
    failureExpectation?.fulfill()
  }
  
  
  func authService(_ authService: AuthService, resolvedAccessToken accessToken: UptakeSSOToken) {
    resolvedAccessToken = accessToken
    tokenExpectation?.fulfill()
  }
}
