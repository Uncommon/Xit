import Cocoa

enum PasswordError: Swift.Error
{
  case invalidURL
  case invalidName
  case itemNotFound
}

public protocol PasswordStorage
{
  func find(host: String, path: String,
            port: UInt16, account: String) -> String?
  func save(host: String, path: String,
            port: UInt16, account: String,
            password: String) throws
  func change(url: URL, newURL: URL?,
              account: String, newAccount: String?,
              password: String) throws
}

extension PasswordStorage
{
  func find(url: URL, account: String) -> String?
  {
    guard let host = url.host
    else { return nil }
    
    return find(host: host, path: url.path,
                port: (url as NSURL).port?.uint16Value ?? 80,
                account: account)
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

final class XTKeychain: PasswordStorage
{
  static let shared: PasswordStorage = XTKeychain()
  
  var keychain: SecKeychain?
  
  private func passwordQueryBase(host: String,
                                 path: String,
                                 port: UInt16,
                                 account: String) -> [CFString: Any]
  {
    var result: [CFString: Any] = [kSecClass: kSecClassInternetPassword,
                                   kSecAttrServer: host,
                                   kSecAttrPort: port,
                                   kSecAttrAccount: account,
                                   ]
    
    if let keychain = self.keychain {
      result[kSecUseKeychain] = keychain
      result[kSecMatchSearchList] = [keychain]
    }
    return result
  }
  
  private func passwordDataQuery(host: String,
                                 path: String,
                                 port: UInt16,
                                 account: String) -> CFDictionary
  {
    var base = passwordQueryBase(host: host, path: path,
                                 port: port, account: account)
    
    base[kSecReturnData] = kCFBooleanTrue
    return base as CFDictionary
  }
  
  /// Gets a password from the keychain.
  func find(host: String, path: String,
            port: UInt16, account: String) -> String?
  {
    var item: CFTypeRef?
    let err = SecItemCopyMatching(passwordDataQuery(host: host, path: path,
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
    var attributes = passwordQueryBase(host: host, path: path, port: port,
                                       account: account)
    
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
    let query = passwordQueryBase(host: host, path: url.path,
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
    guard let passwordData = password.data(using: .utf8)
    else { return nil }
    
    var keychain: SecKeychain?
    let status = passwordData.withUnsafeBytes { pointer in
      return SecKeychainCreate(path, UInt32(passwordData.count), pointer,
                               false, nil, &keychain)
    }
    guard status == noErr,
          let finalKeychain = keychain
    else { return nil }
    
    self.keychainRef = finalKeychain
  }
}
