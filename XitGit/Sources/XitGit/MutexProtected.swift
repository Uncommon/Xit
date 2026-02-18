import Foundation

/// The getter and setter are wrapped in a mutex.
///
/// This doesn't guarantee atomicity for all types, but may be good enough
/// for some cases.
@propertyWrapper
public struct MutexProtected<T>
{
  let mutex = NSRecursiveLock()
  var value: T

  public var wrappedValue: T
  {
    get { mutex.withLock { value } }
    set { mutex.withLock { value = newValue } }
  }

  /// Provides access to the mutex, which is recursive, so it may be useful to
  /// lock it for multiple operations.
  public var projectedValue: NSRecursiveLock { mutex }

  public init(wrappedValue: T)
  {
    self.value = wrappedValue
  }
}
