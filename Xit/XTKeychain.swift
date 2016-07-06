
import Cocoa

final class XTKeychain: NSObject {

  enum Error: ErrorType {
    case InvalidURL
    case ItemNotFound
  }

  /// Gets a password using a URL's host, port and path.
  class func findPassword(url: NSURL, account: String) -> String?
  {
    guard let host = url.host,
          let path = url.path
    else { return nil }
    
    return findPassword(host, path: path,
                        port: url.port?.unsignedShortValue ?? 80,
                        account: account)
  }
  
  /// Gets a password from the keychain.
  class func findPassword(host: String, path: String,
                          port: UInt16, account: String) -> String?
  {
    let (password, _) = findItem(host, path: path, port: port, account: account)
    
    return password
  }
  
  class func findItem(host: String, path: String,
                      port: UInt16, account: String)
                      -> (String?, SecKeychainItemRef?)
  {
    var passwordLength: UInt32 = 0
    var passwordData: UnsafeMutablePointer<Void> = nil
    let nsHost: NSString = host
    let nsPath: NSString = path
    let nsAccount: NSString = account
    let item = UnsafeMutablePointer<SecKeychainItem?>.alloc(1)
    
    let err = SecKeychainFindInternetPassword(
        nil,
        UInt32(nsHost.length), nsHost.UTF8String,
        0, nil,
        UInt32(nsAccount.length), nsAccount.UTF8String,
        UInt32(nsPath.length), nsPath.UTF8String,
        UInt16(port), .HTTP, .HTTPBasic,
        &passwordLength, &passwordData,
        item)
    
    guard err == noErr
    else { return (nil, nil) }
    
    return (NSString(bytes: passwordData, length: Int(passwordLength),
                     encoding: NSUTF8StringEncoding) as? String,
            item.memory)
  }
  
  /// Saves a password to the keychain using a URL's host, port and path.
  class func savePassword(url: NSURL, account: String, password: String) throws
  {
    guard let host = url.host,
          let path = url.path
    else { throw Error.InvalidURL }
    
    try savePassword(host, path: path,
                     port: url.port?.unsignedShortValue ?? 80,
                     account: account,
                     password: password)
  }
  
  /// Saves a password to the keychain.
  class func savePassword(host: String, path: String,
                          port: UInt16, account: String,
                          password: String) throws
  {
    let nsHost: NSString = host
    let nsPath: NSString = path
    let nsAccount: NSString = account
    let nsPassword: NSString = password

    let err = SecKeychainAddInternetPassword(
        nil,
        UInt32(nsHost.length), nsHost.UTF8String,
        0, nil,
        UInt32(nsAccount.length), nsAccount.UTF8String,
        UInt32(nsPath.length), nsPath.UTF8String,
        port,
        .HTTP, .HTTPBasic,
        UInt32(nsPassword.length), nsPassword.UTF8String,
        nil)
    
    guard err == noErr
    else {
      throw NSError(domain: NSOSStatusErrorDomain, code: Int(err), userInfo: nil)
    }
  }
  
  class func changePassword(url: NSURL, account: String, password: String) throws
  {
    guard let host = url.host,
          let path = url.path
    else { throw Error.InvalidURL }
    
    try changePassword(host, path: path,
                       port: url.port?.unsignedShortValue ?? 80,
                       account: account, password: password)
  }
  
  class func changePassword(host: String, path: String,
                            port: UInt16, account: String,
                            password: String) throws
  {
    let (resultPassword, resultItem) = findItem(host, path: path, port: port,
                                                account: account)
    guard let oldPassword = resultPassword,
          let item = resultItem
    else { throw Error.ItemNotFound }
    guard oldPassword != password
    else { return }
    
    let nsPassword: NSString = password
    
    let err = SecKeychainItemModifyAttributesAndData(
        item, nil, UInt32(nsPassword.length), nsPassword.UTF8String)
    
    guard err == noErr
    else {
      throw NSError(domain: NSOSStatusErrorDomain, code: Int(err), userInfo: nil)
    }
  }
}
