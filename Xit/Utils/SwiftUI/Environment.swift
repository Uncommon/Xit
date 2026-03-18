import Foundation
import SwiftUI

extension EnvironmentValues
{
  @Entry var window: NSWindow? = nil
  @Entry var showError: ShowErrorAction = { _ in }
}


// SwiftUI actions are structs with callAsFunction()
// but that seems overcomplicated
typealias ShowErrorAction = (NSError) -> Void
