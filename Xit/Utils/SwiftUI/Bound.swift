import Foundation
import SwiftUI

/// A stored property that can generate its own `Binding`.
@propertyWrapper
class Bound<T>
{
  var wrappedValue: T

  var projectedValue: Binding<T>
  {
    .init(get: { self.wrappedValue }, set: { self.wrappedValue = $0 })
  }

  init(wrappedValue: T)
  {
    self.wrappedValue = wrappedValue
  }
}
