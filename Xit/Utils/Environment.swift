import Foundation
import SwiftUI

struct WindowEnvironmentKey: EnvironmentKey
{
  static let defaultValue: NSWindow = NSApp.mainWindow ?? NSWindow()
}

extension EnvironmentValues
{
  var window: NSWindow
  {
    get { self[WindowEnvironmentKey.self] }
    set { self[WindowEnvironmentKey.self] = newValue }
  }
}
