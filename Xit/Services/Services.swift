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
  
  private var teamCityServices: [String: TeamCityService] = [:]
  private var bitbucketServices: [String: BitbucketService] = [:]
  
  var teamCityServiceList: [TeamCityService]
  { Array(teamCityServices.values) }
  
  private var pullRequestServices: [any PullRequestService]
  { bitbucketServices.values.map { $0 as any PullRequestService } }
  
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
      _ = teamCityService(for: account)
    }
    for account in manager.accounts(ofType: .bitbucketServer) {
      _ = bitbucketService(for: account)
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
    for service in teamCityServices.values {
      service.accountUpdated(oldAccount: oldAccount, newAccount: newAccount)
    }
    for service in bitbucketServices.values {
      service.accountUpdated(oldAccount: oldAccount, newAccount: newAccount)
    }
  }
  
  /// Returns the URLSession-based TeamCity service for the given account.
  func teamCityService(for account: Account) -> TeamCityService?
  {
    let key = Services.accountKey(account)
    
    if let existing = teamCityServices[key] {
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
    
    let service = TeamCityService(
      account: account,
      password: password,
      passwordStorage: passwordStorage,
      authenticationPath: TeamCity.rootPath,
      networkService: network)
    
    teamCityServices[key] = service
    Task {
      await service.attemptAuthentication()
      await service.refreshMetadata()
    }
    return service
  }
  
  func bitbucketService(for account: Account) -> BitbucketService?
  {
    let key = Services.accountKey(account)
    
    if let existing = bitbucketServices[key] {
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
    
    let service = BitbucketService(
      account: account,
      password: password,
      passwordStorage: passwordStorage,
      networkService: network)
    
    if let service {
      bitbucketServices[key] = service
      Task { await service.attemptAuthentication() }
    }
    return service
  }
  
  func pullRequestService(for remote: any Remote) -> (any PullRequestService)?
  {
    pullRequestServices.first { $0.match(remote: remote) }
  }
  
  func teamCityBuildStatus(for remoteURL: String) async -> (TeamCityService, [String])?
  {
    for service in teamCityServices.values {
      let buildTypes = await service.buildTypesForRemote(remoteURL)
      if !buildTypes.isEmpty {
        return (service, buildTypes)
      }
    }
    return nil
  }
  
  func teamCityService(host: String) -> TeamCityService?
  {
    teamCityServices.values.first { $0.account.location.host == host }
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
