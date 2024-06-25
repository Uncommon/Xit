import Foundation
import Combine

public final class TaskQueue: @unchecked Sendable
{
  public enum Error: Swift.Error
  {
    /// Attempt to operate on a queue that is shut down
    case queueShutDown
  }

  let queue: DispatchQueue
  private var queueCount: UInt = 0
  fileprivate(set) var isShutDown = false
  private let lock = NSRecursiveLock()

  private let busyValuePublisher = CurrentValueSubject<Bool, Never>(false)
  public var busyPublisher: AnyPublisher<Bool, Never>
  { busyValuePublisher.eraseToAnyPublisher() }
  
  init(id: String)
  {
    self.queue = DispatchQueue(label: id, attributes: [])
  }

  private func increment()
  {
    lock.withLock {
      queueCount += 1
    }
    busyValuePublisher.value = true
  }

  private func decrement()
  {
    lock.withLock {
      queueCount -= 1
      busyValuePublisher.value = queueCount > 0
    }
  }

  func executeTask(_ block: () -> Void)
  {
    increment()
    block()
    decrement()
  }

  func executeOffMainThread(_ block: @escaping @Sendable () -> Void)
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

  /// Runs an asynchronous block as a queue task.
  func executeAsync(_ block: @Sendable @escaping () async -> Void)
  {
    if isShutDown {
      return
    }
    queue.async {
      let semaphore = DispatchSemaphore(value: 0)

      Task<Void, Never>.detached(priority: .userInitiated) {
        self.increment()
        await block()
        self.decrement()
        semaphore.signal()
      }
      semaphore.wait()
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
