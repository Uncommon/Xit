import Foundation

/// A simple value-holding container. One use is getting values out of Tasks
/// from synchronous code.
class Box<T>
{
  var value: T?

  init(_ value: T? = nil)
  {
    self.value = value
  }
}
