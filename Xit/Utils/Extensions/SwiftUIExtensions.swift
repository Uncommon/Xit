import Foundation
import SwiftUI
import AppKit

extension TextField where Label == EmptyView {
  
  init(text: Binding<String>) {
    self.init(text: text) { EmptyView() }
  }
}
