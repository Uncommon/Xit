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
  
  func teamCityAPI(account: Account) -> XTTeamCityAPI
  {
    let key = XTServices.accountKey(account)
  
    if let api = teamCityServices[key] {
      return api
    }
    else {
      let api = XTTeamCityAPI(baseURL: account.location.absoluteString)
      
      teamCityServices[key] = api
      return api
    }
  }
}

class XTTeamCityAPI : Service {
  
  enum BuildStatus {
    case Unknown
    case Succeded
    case Failed
    case Running
  }
  
  func lastestBuildStatus(branch: String) -> BuildStatus
  {
    let resource =
        self.resource("httpAuth/app/rest/builds/running:any,branch:\(branch)")
    
    // parse out the status and state attributes of the root <build> object
    return .Unknown
  }
}