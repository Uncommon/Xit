import Cocoa
import os
import XitGit

let serviceLogger = Logger(subsystem: Bundle.main.bundleIdentifier!,
                           category: "services")

protocol AccountService: AnyObject
{
  init?(account: Account, password: String)
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
  
  fileprivate static
  let shared = Services(passwordStorage: KeychainStorage.shared)
  
  let passwordStorage: any PasswordStorage
  
  private var teamCityHTTPServices: [String: TeamCityHTTPService] = [:]
  private var bitbucketHTTPServices: [String: BitbucketHTTPService] = [:]
  
  var teamCityHTTPServiceList: [TeamCityHTTPService]
  { Array(teamCityHTTPServices.values) }
  
  private var pullRequestServices: [any PullRequestService]
  { bitbucketHTTPServices.values.map { $0 as any PullRequestService } }
  
  var hasPullRequestService: Bool { !pullRequestServices.isEmpty }
  
  init(passwordStorage: any PasswordStorage)
  {
    self.passwordStorage = passwordStorage
  }
  
  func pullRequestService(forID id: UUID) -> (any PullRequestService)?
  {
    pullRequestServices.first { $0.id == id }
  }
  
  /// Creates an API object for each account so they can start with
  /// authorization and other state info.
  func initializeServices(with manager: AccountsManager)
  {
    for account in manager.accounts(ofType: .teamCity) {
      _ = teamCityHTTPService(for: account)
    }
    for account in manager.accounts(ofType: .bitbucketServer) {
      _ = bitbucketHTTPService(for: account)
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
    for service in teamCityHTTPServices.values {
      service.accountUpdated(oldAccount: oldAccount, newAccount: newAccount)
    }
    for service in bitbucketHTTPServices.values {
      service.accountUpdated(oldAccount: oldAccount, newAccount: newAccount)
    }
  }
  
  /// Returns the URLSession-based TeamCity service for the given account.
  func teamCityHTTPService(for account: Account) -> TeamCityHTTPService?
  {
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
      authenticationPath: TeamCityAPI.rootPath,
      networkService: network)
    
    teamCityHTTPServices[key] = service
    Task {
      await service.attemptAuthentication()
      await service.refreshMetadata()
    }
    return service
  }
  
  func bitbucketHTTPService(for account: Account) -> BitbucketHTTPService?
  {
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
  
  func pullRequestService(for remote: any Remote) -> (any PullRequestService)?
  {
    pullRequestServices.first { $0.match(remote: remote) }
  }
  
  func teamCityHTTPBuildStatus(for remoteURL: String) async -> (TeamCityHTTPService, [String])?
  {
    for service in teamCityHTTPServices.values {
      let buildTypes = await service.buildTypesForRemote(remoteURL)
      if !buildTypes.isEmpty {
        return (service, buildTypes)
      }
    }
    return nil
  }
  
  func teamCityHTTPService(host: String) -> TeamCityHTTPService?
  {
    teamCityHTTPServices.values.first { $0.account.location.host == host }
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
    Services(passwordStorage: MemoryPasswordStorage.shared)
  }()
#endif
}

extension Services.Status: Equatable {}

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
