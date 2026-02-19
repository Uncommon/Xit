import Cocoa
import Siesta
import os

let serviceLogger = Logger(subsystem: Bundle.main.bundleIdentifier!,
                           category: "services")

protocol AccountService: AnyObject
{
  init?(account: Account, password: String)
  func accountUpdated(oldAccount: Account, newAccount: Account)
}

class IdentifiableService: Service, Identifiable
{
  let id = UUID()
}

/// Manages and provides access to all service API instances.
final class Services
{
  /// Feature flag for migrating to new networking stack
  static var useNewNetworking = false
  
  /// Status of server operations such as authentication.
  enum Status
  {
    case unknown
    case notStarted
    case inProgress
    case done
    case failed(Error?)
  }
  
  typealias RepositoryService = IdentifiableService & AccountService
  
  
  fileprivate static
  let shared = Services(passwordStorage: KeychainStorage.shared)
  
  let passwordStorage: any PasswordStorage
  
  private var teamCityServices: [String: TeamCityAPI] = [:]
  private var teamCityHTTPServices: [String: TeamCityHTTPService] = [:]
  private var bitbucketHTTPServices: [String: BitbucketHTTPService] = [:]
  private var bitbucketServices: [String: BitbucketServerAPI] = [:]
  
  private var services: [AccountType: [String: BasicAuthService]] = [:]
  var allServices: [any RepositoryService]
  {
    services.values.flatMap { $0.values }
  }
  
  private var pullRequestServices: [any PullRequestService]
  {
    var result: [any PullRequestService] = allServices.compactMap { $0 as? PullRequestService }
    if Services.useNewNetworking {
      result.append(contentsOf: bitbucketHTTPServices.values.map { $0 as any PullRequestService })
    }
    return result
  }
  
  var serviceMakers: [AccountType: (Account) -> BasicAuthService?] = [:]
  
  init(passwordStorage: any PasswordStorage)
  {
    self.passwordStorage = passwordStorage
    
    let teamCityMaker: (Account) -> TeamCityAPI? = createService(for:)
    let bbsMaker: (Account) -> BitbucketServerAPI? = createService(for:)
    
    serviceMakers[.teamCity] = teamCityMaker
    serviceMakers[.bitbucketServer] = bbsMaker
    
#if false // #available(macOS 13, *) {
    Task {
      let center = NotificationCenter.default
      
      for note in await center.notifications(named: .authenticationStatusChanged) {
        guard let service = note.object as? BasicAuthService
        else { return }
        
        if case .failed(let error) = service.authenticationStatus {
          let serviceName = service.account.type.displayName.rawValue
          let user = service.account.user
          
          if await Self.shouldReauthenticate(
              service: serviceName,
              user: user,
              error: error?.localizedDescription) {
            service.attemptAuthentication()
          }
        }
      }
    }
#else
    NotificationCenter.default.addObserver(
        forName: .authenticationStatusChanged,
        object: nil,
        queue: .main)
    {
      (notification) in
      guard let service = notification.object as? BasicAuthService
      else { return }
      
      if case .failed(let error) = service.authenticationStatus {
        let serviceName = service.account.type.displayName.rawValue
        let user = service.account.user
        
        Task {
          if await Self.shouldReauthenticate(service: serviceName,
                                             user: user,
                                             error: error?.localizedDescription) {
            service.attemptAuthentication()
          }
        }
      }
    }
#endif
  }
  
  func pullRequestService(forID id: UUID) -> (any PullRequestService)?
  {
    allServices.first { $0.id == id } as? PullRequestService
  }
  
  @MainActor
  static func shouldReauthenticate(service: String,
                                   user: String,
                                   error: String?) -> Bool
  {
    guard !(PrefsWindowController.shared.window?.isKeyWindow ?? false)
    else { return false }
    let alert = NSAlert()
    
    alert.messageString = .authFailed(service: service, account: user)
    alert.informativeText = error ?? ""
    alert.addButton(withString: .ok)
    alert.addButton(withString: .retry)
    alert.addButton(withString: .openPrefs)
    switch alert.runModal() {
      case .alertFirstButtonReturn: // OK
        break
      case .alertSecondButtonReturn: // Retry
        return true
      case .alertThirdButtonReturn: // Open prefs
        PrefsWindowController.show(tab: .accounts)
      default:
        break
    }
    return false
  }
  
  /// Creates an API object for each account so they can start with
  /// authorization and other state info.
  func initializeServices(with manager: AccountsManager)
  {
    for account in manager.accounts(ofType: .teamCity) {
      _ = service(for: account)
      if Services.useNewNetworking {
        _ = teamCityHTTPService(for: account)
      }
    }
    for account in manager.accounts(ofType: .bitbucketServer) {
      _ = service(for: account)
      if Services.useNewNetworking {
        _ = bitbucketHTTPService(for: account)
      }
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
  
  func service(for account: Account) -> BasicAuthService?
  {
    let key = Services.accountKey(account)
    if let typeServices = services[account.type],
       let api = typeServices[key] {
      return api
    }
    else if let api = serviceMakers[account.type]?(account) {
      if services[account.type] != nil {
        services[account.type]![key] = api
      }
      else {
        services[account.type] = [key: api]
      }
      return api
    }
    return nil
  }
  
  func buildStatusService(for remoteURL: String)
    -> (BuildStatusService, [String])?
  {
    for service in allServices.compactMap({ $0 as? BuildStatusService }) {
      let buildTypes = service.buildTypesForRemote(remoteURL)
      
      if !buildTypes.isEmpty {
        return (service, buildTypes)
      }
    }
    return nil
  }
  
  /// Returns the TeamCity service object for the given account, or nil if
  /// the password cannot be found.
  func teamCityAPI(for account: Account) -> TeamCityAPI?
  {
    service(for: account) as? TeamCityAPI
  }
  
  /// Returns the URLSession-based TeamCity service for the given account
  /// when the new networking stack is enabled.
  func teamCityHTTPService(for account: Account) -> TeamCityHTTPService?
  {
    guard Services.useNewNetworking
    else { return nil }
    
    let key = Services.accountKey(account)
    
    if let existing = teamCityHTTPServices[key] {
      return existing
    }
    
    guard let password = passwordStorage.find(url: account.location,
                                              account: account.user)
    else {
      serviceLogger.info("No \(account.type.name) password for \(account.user)")
      return nil
    }
    
    let authProvider = BasicAuthProvider(username: account.user,
                                         password: password)
    let network = URLSessionNetworkService(
      session: .init(configuration: .default),
      configuration: .init(headers: [:]),
      authProvider: authProvider)
    
    let service = TeamCityHTTPService(
      account: account,
      password: password,
      passwordStorage: passwordStorage,
      authenticationPath: TeamCityHTTPService.rootPath,
      networkService: network)
    
    teamCityHTTPServices[key] = service
    Task { await service.attemptAuthentication() }
    return service
  }
  
  func bitbucketServerAPI(for account: Account) -> BitbucketServerAPI?
  {
    service(for: account) as? BitbucketServerAPI
  }
  
  func bitbucketHTTPService(for account: Account) -> BitbucketHTTPService?
  {
    guard Services.useNewNetworking
    else { return nil }
    
    let key = Services.accountKey(account)
    
    if let existing = bitbucketHTTPServices[key] {
      return existing
    }
    
    guard let password = passwordStorage.find(url: account.location,
                                              account: account.user)
    else {
      serviceLogger.info("No \(account.type.name) password for \(account.user)")
      return nil
    }
    
    let authProvider = BasicAuthProvider(username: account.user,
                                         password: password)
    let network = URLSessionNetworkService(
      session: .init(configuration: .default),
      configuration: .init(headers: [:]),
      authProvider: authProvider)
    
    let service = BitbucketHTTPService(
      account: account,
      password: password,
      passwordStorage: passwordStorage,
      networkService: network)
    
    if let service {
      bitbucketHTTPServices[key] = service
      Task { await service.attemptAuthentication() }
    }
    return service
  }
  
  func createService<T>(for account: Account) -> T? where T: BasicAuthService
  {
    guard let password = passwordStorage.find(url: account.location,
                                              account: account.user)
    else {
      serviceLogger.info("No \(account.type.name) password for \(account.user)")
      return nil
    }
    
    guard let api = T(account: account, password: password)
    else { return nil }
    
    api.attemptAuthentication()
    return api
  }
  
  func pullRequestService(for remote: any Remote) -> (any PullRequestService)?
  {
    pullRequestServices.first { $0.match(remote: remote) }
  }
}

extension Services
{
  public static var xit: Services
  {
#if DEBUG
    return AppTesting.defaults == .standard ? .shared : .testing
#else
    return shared
#endif
  }
  
#if DEBUG
  static let testing: Services = {
    let result = Services(passwordStorage: MemoryPasswordStorage.shared)
    for type in AccountType.allCases {
      result.serviceMakers[type] = MockAuthService.maker
    }
    return result
  }()
#endif
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
