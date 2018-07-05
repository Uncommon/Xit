import Foundation

class ObserverCollection
{
  var observers: [NSObjectProtocol] = []
  
  func addObserver(forName name: NSNotification.Name,
                   object obj: Any?, queue: OperationQueue?,
                   using block: @escaping (Notification) -> Void)
  {
    observers.append(NotificationCenter.default.addObserver(
        forName: name, object: obj, queue: queue, using: block))
  }
  
  deinit
  {
    for observer in observers {
      NotificationCenter.default.removeObserver(observer)
    }
  }
}
