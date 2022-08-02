import Foundation

public struct ValueContainer<T>
{
  let wrappedValue: T
}

/// Assuming `payload` points to an instance of `ValueContainer<T>`, returns
/// the contained value.
func fromContainer<T>(_ payload: UnsafeMutableRawPointer) -> T
{
  return payload.bindMemory(to: ValueContainer<T>.self, capacity: 1)
      .pointee.wrappedValue
}
