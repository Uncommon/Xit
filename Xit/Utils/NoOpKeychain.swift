import Foundation

final class NoOpKeychain: PasswordStorage
{
  func find(host: String, path: String,
            protocol: PasswordProtocol?,
            port: UInt16, account: String?) -> String?
  { nil }
  func save(host: String, path: String,
            port: UInt16, account: String,
            password: String) throws {}
  func change(url: URL, newURL: URL?,
              account: String, newAccount: String?,
              password: String) throws {}
}
