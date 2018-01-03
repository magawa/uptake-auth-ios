import Foundation



/** SSO Provider types which can be used to authenticate with through Uptake Auth Service */
public enum ProviderType: String {
  /**
   CAT's [Corporate Web Security](https://login.cat.com/)
   */
  case cws = "cws"
  
  
  /**
   Uptake's Auth Login
   */
  case oneLogin = "onelogin"
}



