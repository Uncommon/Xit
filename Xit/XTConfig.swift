import Cocoa

/// Provides access to repository config options. This class is an exception to
/// the rule that direct Objective Git usage should be avoided outside of
/// `XTRepository`.
class XTConfig: NSObject {
  
  unowned let repository: XTRepository
  let config: GTConfiguration?
  var xitConfig: [String: String] = [:]
  
  var xitConfigURL: NSURL?
  {
    return repository.gitDirectoryURL.URLByAppendingPathComponent("xit-config.plist")
  }
  
  init(repository: XTRepository)
  {
    self.repository = repository
    self.config = try? repository.gtRepo.configuration()
    if config == nil {
      NSLog("Could not get config")
    }
    
    super.init()
    
    loadXitConfig()
  }
  
  final func loadXitConfig()
  {
    guard let xitConfigURL = xitConfigURL
    else {
      NSLog("Can't make Xit config URL")
      return
    }
    guard let configContents = NSMutableDictionary(contentsOfURL: xitConfigURL)
    else {
      NSLog("Can't read xit-config")
      return
    }
    guard let configCopy = configContents.mutableCopy() as? [String : String]
    else {
      NSLog("Can't copy config contents")
      return
    }
    
    xitConfig = configCopy
  }
  
  final func saveXitConfig()
  {
    guard let xitConfigURL = xitConfigURL
      else {
        NSLog("Can't make Xit config URL")
        return
    }
    
    if !(xitConfig as NSDictionary).writeToURL(xitConfigURL, atomically: true) {
      NSLog("Save config failed")
    }
  }
  
  /// Returns the `fetch.prune` setting.
  final func fetchPrune() -> Bool
  {
    guard let config = config else { return false }
    return config.boolForKey("fetch.prune")
  }
  
  /// Returns the prune setting for `remote`, or falls back to the general
  /// `fetch.prune` setting.
  final func fetchPrune(remote: String) -> Bool
  {
    guard let config = config else { return false }
    if config.boolForKey("remote.\(remote).prune") {
      return true
    }
    return fetchPrune()
  }
  
  /// Returns true if `--no-tags` is set for `remote.<remote>.tagOpt`.
  final func fetchTags(remote: String) -> Bool
  {
    guard let config = config else { return true }
    if config.stringForKey("remote.\(remote).tagOpt") == "--no-tags" {
      return false
    }
    return true
  }
  
  final func teamCityAccountKey(remote: String) -> String
  {
    return "remote.\(remote).teamCityAccount"
  }
  
  /// Returns the TeamCity account chosen for the remote, if any.
  final func teamCityAccount(remote: String) -> Account?
  {
    guard let accountString = xitConfig[teamCityAccountKey(remote)]
    else { return nil }
    guard let url = NSURLComponents(string: accountString)
    else {
      NSLog("Stored URL not parseable: \(accountString)")
      return nil
    }
    let user = url.user ?? ""
    
    url.user = nil
    
    guard let finalURL = url.URL
    else {
      NSLog("Couldn't reconstruct URL: \(accountString)")
      return nil
    }
    
    return Account(type: .TeamCity, user: user, location: finalURL)
  }
  
  /// Sets (or clears) the TeamCity account for the remote.
  final func setTeamCityAccount(remote: String, account: Account?)
  {
    if let account = account {
      guard account.type == .TeamCity
      else {
        NSLog("Wrong account type: \(account.type.name)")
        return
      }
      guard let url = NSURLComponents(URL: account.location,
                                      resolvingAgainstBaseURL: false)
      else {
        NSLog("Couldn't parse URL from account: \(account.location.absoluteString)")
        return
      }
      
      url.user = account.user
      xitConfig[teamCityAccountKey(remote)] = url.string
    }
    else {
      xitConfig.removeValueForKey(teamCityAccountKey(remote))
    }
  }
}
