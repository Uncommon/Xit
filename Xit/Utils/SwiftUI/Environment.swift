import Foundation
import SwiftUI

struct WindowEnvironmentKey: EnvironmentKey
{
  static let defaultValue: NSWindow? = nil
}

extension EnvironmentValues
{
  var window: NSWindow?
  {
    get { self[WindowEnvironmentKey.self] }
    set { self[WindowEnvironmentKey.self] = newValue }
  }
}


// SwiftUI actions are structs with callAsFunction()
// but that seems overcomplicated
typealias ShowErrorAction = (NSError) -> Void

struct ShowErrorActionEnvironmentKey: EnvironmentKey
{
  static let defaultValue: ShowErrorAction = { _ in }
}

extension EnvironmentValues
{
  /// Action that presents an alert with the given error details
  var showError: ShowErrorAction
  {
    get { self[ShowErrorActionEnvironmentKey.self] }
    set { self[ShowErrorActionEnvironmentKey.self] = newValue }
  }
}
