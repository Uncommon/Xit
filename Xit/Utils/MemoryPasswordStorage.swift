import Foundation

final class MemoryPasswordStorage: PasswordStorage, @unchecked Sendable // protected by lock
{
  static let shared: MemoryPasswordStorage = .init()

  struct Key: Hashable // until tuples are hashable
  {
    let url: URL
    let user: String
  }

  private var store: [Key: String] = [:]
  private var lock = NSRecursiveLock()

  func find(host: String, path: String,
            protocol: PasswordProtocol?, port: UInt16,
            account: String?) -> String? {
    guard let account = account,
          let url = URL(host: host, path: path,
                        protocol: `protocol`, port: port)
    else { return nil }

    return lock.withSync { store[Key(url: url, user: account)] }
  }

  func save(host: String, path: String,
            port: UInt16, account: String,
            password: String) throws
  {
    guard let url = URL(host: host, path: path,
                        protocol: .http, port: port)
    else {
      throw PasswordError.invalidURL
    }

    lock.withSync {
      store[Key(url: url, user: account)] = password
    }
  }

  func change(url: URL, newURL: URL?,
              account: String, newAccount: String?, password: String) throws
  {
    lock.withSync {
      if newURL != nil || newAccount != nil {
        let newURL = newURL ?? url
        let newAccount = newAccount ?? account
        let key = Key(url: newURL, user: newAccount)

        store.removeValue(forKey: Key(url: url, user: account))
        store[key] = password
      }
      else {
        store[Key(url: url, user: account)] = password
      }
    }
  }
}

extension URL
{
  init?(host: String, path: String,
        protocol: PasswordProtocol?, port: UInt16)
  {
    var components = URLComponents()
    let `protocol` = `protocol` ?? .http

    components.scheme = `protocol`.rawValue
    components.port = Int(port)
    components.path = path

    guard let url = components.url
    else { return nil }

    self = url
  }
}
