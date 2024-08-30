import Foundation
import SwiftUI

extension TextField where Label == EmptyView {
  
  init(text: Binding<String>) {
    self.init(text: text) { EmptyView() }
  }
}
