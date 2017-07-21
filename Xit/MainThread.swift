import Foundation

/// Utility functions for executing on the main thread.
class MainThread
{
  /// Executes `block` on the main thread, either immediately if this is the
  /// main thread, or asynchronously.
  static func async(_ block: @escaping () -> Void)
  {
    if pthread_main_np() == 0 {
      DispatchQueue.main.async(execute: block)
    }
    else {
      block()
    }
  }
  
  /// Executes `block` on the main thread, either immediately if this is the
  /// main thread, or synchronously.
  static func sync(_ block: @escaping () -> Void)
  {
    if pthread_main_np() == 0 {
      DispatchQueue.main.sync(execute: block)
    }
    else {
      block()
    }
  }
}

/// Similar to Objective-C's `@synchronized`
/// - parameter object: Token object for the lock
/// - parameter block: Block to execute inside the lock
func synchronized(_ object: NSObject, block: () -> Void)
{
  objc_sync_enter(object)
  block()
  objc_sync_exit(object)
}
