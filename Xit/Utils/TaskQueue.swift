import Foundation

public class TaskQueue: NSObject
{
  enum Error: Swift.Error
  {
    /// Attempt to operate on a queue that is shut down
    case queueShutDown
  }

  @objc let queue: DispatchQueue
  var queueCount: UInt = 0
  fileprivate(set) var isShutDown = false
  
  @objc var busy: Bool
  { queueCount > 0 }
  
  init(id: String)
  {
    self.queue = DispatchQueue(label: id, attributes: [])
  }
  
  private func updateQueueCount(_ delta: Int)
  {
    DispatchQueue.main.async {
      [weak self] in
      guard let self = self
      else { return }
      
      self.changingValue(forKey: #keyPath(busy)) {
        self.queueCount = UInt(Int(self.queueCount) + delta)
      }
    }
  }
  
  func executeTask(_ block: () -> Void)
  {
    updateQueueCount(1)
    block()
    updateQueueCount(-1)
  }
  
  func executeOffMainThread(_ block: @escaping () -> Void)
  {
    if Thread.isMainThread {
      if !isShutDown {
        queue.async {
          [weak self] in
          self?.executeTask(block)
        }
      }
    }
    else {
      executeTask(block)
    }
  }

  /// Runs the block synchronously on the task queue when called from the main
  /// thread, or inline otherwise.
  func syncOffMainThread<T>(_ block: () throws -> T) throws -> T
  {
    if Thread.isMainThread {
      if isShutDown {
        throw Error.queueShutDown
      }
      else {
        return try queue.sync(execute: block)
      }
    }
    else {
      return try block()
    }
  }
  
  @objc
  func wait()
  {
    WaitForQueue(queue)
  }
  
  @objc
  func shutDown()
  {
    isShutDown = true
  }
}
