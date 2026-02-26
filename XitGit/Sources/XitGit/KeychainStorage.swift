import Foundation
import Security

private enum PasswordProtocol
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

final class KeychainStorage
{
  static let shared = KeychainStorage()
  
  private init() {}
  
  private func passwordDataQuery(host: String,
                                 path: String,
                                 protocol: PasswordProtocol?,
                                 port: UInt16,
                                 account: String?) -> CFDictionary
  {
    var query: [CFString: Any] = [
      kSecClass: kSecClassInternetPassword,
      kSecAttrServer: host,
      kSecAttrPath: path,
      kSecAttrPort: port,
      kSecReturnData: kCFBooleanTrue as Any
    ]
    if let account {
      query[kSecAttrAccount] = account
    }
    if let `protocol` = `protocol` {
      query[kSecAttrProtocol] = `protocol`.string
    }
    return query as CFDictionary
  }
  
  private func find(host: String,
                    path: String,
                    protocol: PasswordProtocol?,
                    port: UInt16,
                    account: String?) -> String?
  {
    var item: CFTypeRef?
    let status = SecItemCopyMatching(
      passwordDataQuery(host: host,
                        path: path,
                        protocol: `protocol`,
                        port: port,
                        account: account),
      &item
    )
    guard status == errSecSuccess,
          let data = item as? Data,
          let password = String(data: data, encoding: .utf8)
    else { return nil }
    return password
  }
  
  func find(url: URL, account: String? = nil) -> String?
  {
    guard let host = url.host
    else { return nil }
    let port = UInt16(url.port ?? url.defaultPort)
    let user = account?.nilIfEmpty ?? url.user ?? url.impliedUserName
    
    return find(host: host, path: url.path,
                protocol: PasswordProtocol(url: url),
                port: port, account: user)
        ?? find(host: host, path: url.path,
                protocol: nil,
                port: port, account: user)
  }
}

extension URL
{
  var impliedUserName: String?
  {
    guard let primary = host?.components(separatedBy: ".").suffix(2)
      .joined(separator: ".")
    else { return nil }
    
    switch primary.lowercased() {
      case "github.com", "gitlab.com":
        return path.pathComponents.dropFirst().first
      default:
        return nil
    }
  }
}
