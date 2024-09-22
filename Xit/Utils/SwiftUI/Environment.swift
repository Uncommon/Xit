import Foundation
import SwiftUI

extension EnvironmentValues
{
  @Entry var window: NSWindow? = nil
  @Entry var dateFormatStyle: Date.FormatStyle = .dateTime
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
