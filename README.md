# UptakeAuth
![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat) ![API docs](http://mobile-toolkit-docs.services.common.int.uptake.com/docs/uptake-auth-ios/badge.svg)

An authentication library for Uptake services.

## Usage
[UptakeAuthUI](https://github.com/UptakeMobile/uptake-auth-ui-ios) provides a full-featured frontend to this library. But if you want to roll your own, the authentication workflow looks something like this:

1. Get an API key and decide on the environment (staging, production, &c.).
1. Make some class conform to the `AuthServiceDelegate` protocol.
1. Create an `AuthService` instance, passing in the delegate.
1. Decide on a provider (CWS, OneLogin, &c.) and a callback URL. The callback URL should have a unique scheme your app is registered to handle.
1. Use the `AuthService` instance to generate a login URL (`getAuthenticationURL`) with the given provider and your callback URL.
1. Navigate to the resulting authentication URL in some sort of embedded browser and display it to the user.
1. If the user successfully authenticates, the browser will attempt to open the callback URL. If your app has been properly configured as a handler of this URL's scheme, `application(_:open:options:)` will be called in your app delegate. Pass the URL on to your AuthService instance (via `processAuth0Callback`)
1. Your delegate should be called with `authService(_:accessToken:)`. Take the token and prosper.

## Logging
Logging can be enabled by setting the environment variable `UPTAKE_AUTH_DEBUGGING` to any non-nil value ("1" is traditional).
