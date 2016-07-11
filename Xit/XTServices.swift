import Cocoa
import Siesta

/// Manages and provides access to all service API instances.
class XTServices: NSObject {
  
  static let services = XTServices()
  
  var teamCityServices: [String: XTTeamCityAPI] = [:]
  
  static func accountKey(account: Account) -> String
  {
    return "\(account.user)@\(account.location.host)"
  }
  
  /// Returns the TeamCity service object for the given account, or nil if
  /// the psasword cannot be found.
  func teamCityAPI(account: Account) -> XTTeamCityAPI?
  {
    let key = XTServices.accountKey(account)
  
    if let api = teamCityServices[key] {
      return api
    }
    else {
      guard let password = XTKeychain.findPassword(account.location,
                                                   account: account.user)
      else { return nil }
      
      let api = XTTeamCityAPI(user: account.user,
                              password: password,
                              baseURL: account.location.absoluteString)
      
      teamCityServices[key] = api
      return api
    }
  }
}


/// Abstract service class that handles HTTP basic authentication.
class XTBasicAuthService : Service {
  
  init(user: String, password: String,
       baseURL: String?) {
    super.init(baseURL: baseURL)
  
    if let data = "\(user):\(password)"
        .dataUsingEncoding(NSUTF8StringEncoding)?
        .base64EncodedStringWithOptions([]) {
      configure { (builder) in
        builder.config.headers["Authorization"] = "Basic \(data)"
      }
    }
    else {
      NSLog("Couldn't construct auth header for \(user) @ \(baseURL)")
    }
  }
  
}


class XTTeamCityAPI : XTBasicAuthService {
  
  enum BuildStatus {
    case Unknown
    case Succeded
    case Failed(String)  // Failure reason
    case Running(Float)  // Percentage complete
  }
  
  override init(user: String, password: String, baseURL: String?)
  {
    super.init(user: user, password: password, baseURL: baseURL)
    
    configure("*", requestMethods: nil, description: nil) {
      $0.config.pipeline[.parsing].add(ResponseContentTransformer() {
          content, entity in
        return try? NSXMLDocument(data: content, options: 0)
      })
    }
  }
  
  func lastestBuildStatus(branch: String) -> Resource
  {
    return self.resource(
        "httpAuth/app/rest/builds/running:any,branch:\(branch)")
  }
}
