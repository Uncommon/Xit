import Foundation

func WaitForQueue(_ queue: DispatchQueue?)
{
  guard let queue
  else { return }
  
  let semaphore = DispatchSemaphore(value: 0)
  queue.async {
    semaphore.signal()
  }
  
  if Thread.isMainThread {
    while semaphore.wait(timeout: .now()) != .success {
      _ = RunLoop.current.run(mode: .default,
                              before: Date(timeIntervalSinceNow: 0.01))
    }
  }
  else {
    semaphore.wait()
  }
}
