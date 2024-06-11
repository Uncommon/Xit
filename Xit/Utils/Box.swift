import Foundation

/// A simple value-holding container for getting values out of Tasks
/// from synchronous code. Marked as unchecked Sendable so handle with care.
class Box<T>: @unchecked Sendable
{
  var value: T?

  init(_ value: T? = nil)
  {
    self.value = value
  }
}
