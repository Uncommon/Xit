import Foundation

class ObserverCollection
{
  var observers: [NSNotification.Name: NSObjectProtocol] = [:]
  
  func addObserver(forName name: NSNotification.Name,
                   object obj: Any?, queue: OperationQueue?,
                   using block: @escaping (Notification) -> Void)
  {
    assert(observers[name] == nil)
    observers[name] = NotificationCenter.default.addObserver(
        forName: name, object: obj, queue: queue, using: block)
  }
  
  deinit
  {
    for observer in observers.values {
      NotificationCenter.default.removeObserver(observer)
    }
  }
}
