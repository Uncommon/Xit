import Foundation
import Combine

public final class TaskQueue
{
  public enum Error: Swift.Error
  {
    /// Attempt to operate on a queue that is shut down
    case queueShutDown
  }

  let queue: DispatchQueue
  var queueCount: UInt = 0
  {
    didSet { busyValuePublisher.value = queueCount > 0 }
  }
  fileprivate(set) var isShutDown = false

  private let busyValuePublisher = CurrentValueSubject<Bool, Never>(false)
  public var busyPublisher: AnyPublisher<Bool, Never>
  { busyValuePublisher.eraseToAnyPublisher() }
  
  init(id: String)
  {
    self.queue = DispatchQueue(label: id, attributes: [])
  }
  
  func executeTask(_ block: () -> Void)
  {
    queueCount += 1
    block()
    queueCount -= 1
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
  
  func wait()
  {
    WaitForQueue(queue)
  }
  
  func shutDown()
  {
    isShutDown = true
  }
}
