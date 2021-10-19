import Cocoa
import Siesta

extension Siesta.Resource
{
  /// Either executes the closure with the resource's data, or schedules it
  /// to run later when the data is available.
  func useData(owner: AnyObject, closure: @escaping (Siesta.Entity<Any>) -> Void)
  {
    if isUpToDate, let data = latestData {
      closure(data)
    }
    else {
      addObserver(owner: owner) {
        (resource, event) in
        if case .newData = event,
           let data = resource.latestData {
          closure(data)
        }
      }
      loadIfNeeded()
    }
  }
}

protocol AccountService
{
  func accountUpdated(oldAccount: Account, newAccount: Account)
}

/// Manages and provides access to all service API instances.
final class Services
{
  /// Status of server operations such as authentication.
  enum Status
  {
    case unknown
    case notStarted
    case inProgress
    case done
    case failed(Error?)
  }
  
  typealias RepositoryService = Service & AccountService
  
  static let shared = Services()
  
  private var teamCityServices: [String: TeamCityAPI] = [:]
  private var bitbucketServices: [String: BitbucketServerAPI] = [:]
  
  var allServices: [RepositoryService]
  {
    let tcServices: [RepositoryService] = Array(teamCityServices.values)
    let bbServices: [RepositoryService] = Array(bitbucketServices.values)
    let result: [RepositoryService] = tcServices + bbServices
    // for testing
    //  + [FakePRService()]
    
    return result
  }
  
  init()
  {
    NotificationCenter.default.addObserver(
        forName: .authenticationStatusChanged,
        object: nil,
        queue: .main)
    {
      (notification) in
      guard let service = notification.object as? BasicAuthService
      else { return }
        
      if case .failed(let error) = service.authenticationStatus {
        guard !(PrefsWindowController.shared.window?.isKeyWindow ?? false)
        else { return }
        let alert = NSAlert()
        
        alert.messageString = .authFailed(
                service: service.account.type.displayName.rawValue,
                account: service.account.user)
        alert.informativeText = error?.localizedDescription ?? ""
        alert.addButton(withString: .ok)
        alert.addButton(withString: .retry)
        alert.addButton(withString: .openPrefs)
        switch alert.runModal() {
          case .alertFirstButtonReturn: // OK
            break
          case .alertSecondButtonReturn: // Retry
            service.attemptAuthentication()
          case .alertThirdButtonReturn: // Open prefs
            PrefsWindowController.show(tab: .accounts)
          default:
            break
        }
      }
    }
  }
  
  /// Creates an API object for each account so they can start with
  /// authorization and other state info.
  func initializeServices()
  {
    guard !UserDefaults.standard.bool(forKey: "noServices")
    else { return }
    
    for account in AccountsManager.manager.accounts(ofType: .teamCity) {
      _ = teamCityAPI(account)
    }
    for account in AccountsManager.manager.accounts(ofType: .bitbucketServer) {
      _ = bitbucketServerAPI(account)
    }
  }
  
  private static func accountKey(_ account: Account) -> String
  {
    if let host = account.location.host {
      return "\(account.user)@\(host)"
    }
    else {
      return account.user
    }
  }
  
  /// Notifies all services that an account has been updated
  func accountUpdated(oldAccount: Account, newAccount: Account)
  {
    for service in allServices {
      service.accountUpdated(oldAccount: oldAccount, newAccount: newAccount)
    }
  }

  /// Returns the TeamCity service object for the given account, or nil if
  /// the password cannot be found.
  func teamCityAPI(_ account: Account) -> TeamCityAPI?
  {
    let key = Services.accountKey(account)
  
    if let api = teamCityServices[key] {
      return api
    }
    else {
      guard let password = XTKeychain.shared.find(url: account.location,
                                                  account: account.user)
      else {
        NSLog("No password found for \(key)")
        return nil
      }
      
      guard let api = TeamCityAPI(account: account, password: password)
      else { return nil }
      
      api.attemptAuthentication()
      teamCityServices[key] = api
      return api
    }
  }
  
  func bitbucketServerAPI(_ account: Account) -> BitbucketServerAPI?
  {
    let key = Services.accountKey(account)
    
    if let api = bitbucketServices[key] {
      return api
    }
    else {
      guard let password = XTKeychain.shared.find(url: account.location,
                                                  account: account.user)
      else {
        NSLog("No password found for \(key)")
        return nil
      }
      
      guard let api = BitbucketServerAPI(account: account, password: password)
      else { return nil }
      
      api.attemptAuthentication()
      bitbucketServices[key] = api
      return api
    }
  }
  
  func pullRequestService(remote: Remote) -> PullRequestService?
  {
    let prServices = allServices.compactMap { $0 as? PullRequestService }
    
    return prServices.first { $0.match(remote: remote) }
  }
}


extension Services.Status: Equatable
{
}

// This doesn't come for free because of the associated value on .failed
func == (a: Services.Status, b: Services.Status) -> Bool
{
  switch (a, b) {
    case (.unknown, .unknown),
         (.notStarted, .notStarted),
         (.inProgress, .inProgress),
         (.done, .done):
      return true
    case (.failed, .failed):
      return true
    default:
      return false
  }
}


/// Protocol to be implemented by all concrete API classes.
protocol ServiceAPI
{
  var type: AccountType { get }
}


public func XMLResponseTransformer(
    _ transformErrors: Bool = true) -> Siesta.ResponseTransformer
{
  return Siesta.ResponseContentTransformer<Data, XMLDocument>(
      transformErrors: transformErrors) {
    (entity: Siesta.Entity<Data>) throws -> XMLDocument? in
    try XMLDocument(data: entity.content, options: [])
  }
}
