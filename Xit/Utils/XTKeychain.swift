import Cocoa

enum PasswordError: Swift.Error
{
  case invalidURL
  case invalidName
  case itemNotFound
}

public protocol PasswordStorage
{
  func findPassword(host: String, path: String,
                    port: UInt16, account: String) -> String?
  func savePassword(host: String, path: String,
                    port: UInt16, account: String,
                    password: String) throws
  func changePassword(url: URL, newURL: URL?,
                      account: String, newAccount: String?,
                      password: String) throws
}

extension PasswordStorage
{
  func findPassword(url: URL, account: String) -> String?
  {
    guard let host = url.host
    else { return nil }
    
    return findPassword(host: host, path: url.path,
                        port: (url as NSURL).port?.uint16Value ?? 80,
                        account: account)
  }
  
  func savePassword(url: URL, account: String, password: String) throws
  {
    guard let host = url.host
    else { throw PasswordError.invalidURL }
    
    try savePassword(host: host, path: url.path,
                     port: (url as NSURL).port?.uint16Value ?? 80,
                     account: account, password: password)
  }
}

final class XTKeychain: PasswordStorage
{
  static let shared: PasswordStorage = XTKeychain()
  
  private func passwordQueryBase(host: String,
                                 path: String,
                                 port: UInt16,
                                 account: String) -> [CFString: Any]
  {
    return [kSecClass: kSecClassInternetPassword,
            kSecAttrServer: host,
            kSecAttrPort: port,
            kSecAttrAccount: account,
            ]
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
  func findPassword(host: String, path: String,
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
  func savePassword(host: String, path: String,
                    port: UInt16, account: String,
                    password: String) throws
  {
    let status = SecItemAdd([kSecClass: kSecClassInternetPassword,
                             kSecAttrServer: host,
                             kSecAttrPort: port,
                             kSecAttrAccount: account,
                             kSecValueData: password,
                             ] as CFDictionary, nil)
    
    
    guard status == noErr
    else {
      throw NSError(osStatus: status)
    }
  }
  
  func changePassword(url: URL, newURL: URL?,
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
