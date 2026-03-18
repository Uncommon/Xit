import Foundation
import SwiftUI

extension Binding
{
  /// Returns a binding that sets whether or not the given element is included
  /// in the set.
  func binding<S>(for element: S) -> Binding<Bool>
    where Value == Set<S>
  {
    return .init(
      get: { self.wrappedValue.contains(element) },
      set: {
        if $0
        {
          self.wrappedValue.insert(element)
        }
        else
        {
          self.wrappedValue.remove(element)
        }
      })
  }
}

extension TextField where Label == EmptyView {
  
  init(text: Binding<String>) {
    self.init(text: text) { EmptyView() }
  }
}
