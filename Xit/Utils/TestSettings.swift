import Foundation

#if DEBUG
enum TestSettings
{
  enum Defaults: String, CaseIterable
  {
    case standard, tempEmpty, tempAccounts
  }

  nonisolated(unsafe) // only set in initialize()
  private(set) static var defaults: Defaults = .standard

  static let tempAccountsData: [Account] = [
    .init(type: .gitHub, user: "This guy",
          location: .init(string: "https://github.com")!, id: .init()),
    .init(type: .gitLab, user: "Henry",
          location: .init(string: "https://gitlab.com")!, id: .init()),
  ]

  @MainActor
  static func initialize()
  {
    var defaultsOption = false

    for arg in ProcessInfo.processInfo.arguments {
      if arg == "--defaults" {
        defaultsOption = true
      }
      else if defaultsOption {
        defaults = .init(rawValue: arg) ?? .standard
        defaultsOption = false
      }
    }

    if defaults == .tempAccounts {
      UserDefaults.testing.accounts = tempAccountsData
    }
  }
}
#endif
