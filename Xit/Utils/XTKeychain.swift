import Cocoa

enum PasswordError: Swift.Error
{
  case invalidURL
  case invalidName
  case itemNotFound
  case passwordNotSpecified
}

public enum PasswordProtocol
{
  case http
  case https
  
  var string: CFString
  {
    switch self {
      case .http: return kSecAttrProtocolHTTP
      case .https: return kSecAttrProtocolHTTPS
    }
  }
  
  init?(url: URL)
  {
    switch url.scheme {
      case "http": self = .http
      case "https": self = .https
      default: return nil
    }
  }
}

public protocol PasswordStorage
{
  func find(host: String, path: String,
            protocol: PasswordProtocol?,
            port: UInt16, account: String?) -> String?
  func save(host: String, path: String,
            port: UInt16, account: String,
            password: String) throws
  func change(url: URL, newURL: URL?,
              account: String, newAccount: String?,
              password: String) throws
}

extension PasswordStorage
{
  func find(url: URL, account: String? = nil) -> String?
  {
    guard let host = url.host
    else { return nil }
    let port = UInt16(url.port ?? url.defaultPort)
    let user = account?.nilIfEmpty ?? url.user ?? url.impliedUserName
    
    return find(host: host, path: url.path,
                protocol: PasswordProtocol(url: url),
                port: port,
                account: user)
        ?? find(host: host, path: url.path,
                protocol: nil,
                port: port,
                account: user)
  }
  
  func find(account: Account) -> String?
  {
    guard let host = account.location.host
    else { return nil }
    
    return find(host: host, path: account.location.path,
                protocol: nil,
                port: UInt16(account.location.port ?? 80),
                account: account.user)
  }
  
  func save(url: URL, account: String, password: String) throws
  {
    guard let host = url.host
    else { throw PasswordError.invalidURL }
    
    try save(host: host, path: url.path,
             port: (url as NSURL).port?.uint16Value ?? 80,
             account: account, password: password)
  }
}

extension URL
{
  /// The user name that may be implied by the URL's path.
  var impliedUserName: String?
  {
    guard let primary = host?.components(separatedBy: ".").suffix(2)
                             .joined(separator: ".")
    else { return nil }

    switch primary.lowercased() {
      case "github.com", "gitlab.com":
        // first component is "/"
        return path.pathComponents.dropFirst().first
      default:
        return nil
    }
  }
}

final class XTKeychain: PasswordStorage
{
  static let shared: PasswordStorage = XTKeychain()
  
  var keychain: SecKeychain?
  
  private func passwordQueryBase(host: String,
                                 path: String,
                                 protocol: PasswordProtocol?,
                                 port: UInt16,
                                 account: String?) -> [CFString: Any]
  {
    var result: [CFString: Any] = [kSecClass: kSecClassInternetPassword,
                                   kSecAttrServer: host,
                                   //kSecAttrPort: port,
                                   ]
    
    if let account = account {
      result[kSecAttrAccount] = account
    }
    if let keychain = self.keychain {
      result[kSecUseKeychain] = keychain
      result[kSecMatchSearchList] = [keychain]
    }
    if let protocolString = `protocol`?.string {
      result[kSecAttrProtocol] = protocolString
    }
    return result
  }
  
  private func passwordDataQuery(host: String,
                                 path: String,
                                 protocol: PasswordProtocol?,
                                 port: UInt16,
                                 account: String?) -> CFDictionary
  {
    var base = passwordQueryBase(host: host, path: path,
                                 protocol: `protocol`,
                                 port: port, account: account)
    
    base[kSecReturnData] = kCFBooleanTrue
    return base as CFDictionary
  }
  
  /// Gets a password from the keychain.
  func find(host: String, path: String,
            protocol: PasswordProtocol?,
            port: UInt16, account: String?) -> String?
  {
    var item: CFTypeRef?
    let err = SecItemCopyMatching(passwordDataQuery(host: host, path: path,
                                                    protocol: `protocol`,
                                                    port: port, account: account),
                                  &item)
    
    guard err == errSecSuccess,
          let passwordData = item as? Data,
          let password = String(data: passwordData, encoding: .utf8)
    else { return nil }
    
    return password
  }
  
  /// Saves a password to the keychain.
  func save(host: String, path: String,
            port: UInt16, account: String,
            password: String) throws
  {
    var attributes = passwordQueryBase(host: host, path: path, protocol: nil,
                                       port: port, account: account)
    
    attributes[kSecValueData] = password
    
    let status = SecItemAdd(attributes as CFDictionary, nil)
    
    guard status == noErr
    else {
      throw NSError(osStatus: status)
    }
  }
  
  func change(url: URL, newURL: URL?,
              account: String, newAccount: String?,
              password: String) throws
  {
    guard let host = url.host
    else { throw PasswordError.invalidURL }
    let query = passwordQueryBase(host: host, path: url.path, protocol: nil,
                                  port: UInt16(url.port ?? 80), account: account)
    var update: [CFString: Any] = [kSecValueData: password.data(using: .utf8)!]
    
    if let newAccount = newAccount {
      update[kSecAttrAccount] = newAccount
    }
    if let newURL = newURL {
      guard let newHost = newURL.host
      else { throw PasswordError.invalidURL }
      
      update[kSecAttrServer] = newHost
      update[kSecAttrPath] = newURL.path
    }
    
    let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
    
    switch status {
      case noErr:
        break
      case errSecItemNotFound:
        throw PasswordError.itemNotFound
      default:
        throw NSError(osStatus: status)
    }
  }
}

class Keychain
{
  let keychainRef: SecKeychain
  
  init?(path: String, password: String, promptUser: Bool)
  {
    var keychain: SecKeychain?
    let status = SecKeychainCreate(path, UInt32(password.utf8.count), password,
                                   false, nil, &keychain)
    guard status == noErr,
          let finalKeychain = keychain
    else { return nil }
    
    self.keychainRef = finalKeychain
  }
}
