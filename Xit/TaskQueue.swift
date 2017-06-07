import Foundation

class TaskQueue: NSObject
{
  let queue: DispatchQueue
  let group = DispatchGroup()
  var queueCount: UInt = 0
  fileprivate(set) var isShutDown = false
  
  var busy: Bool
  {
    return queueCount > 0
  }
  
  init(id: String)
  {
    self.queue = DispatchQueue(label: id, attributes: [])
  }
  
  private func updateQueueCount(_ delta: Int)
  {
    DispatchQueue.main.async {
      self.willChangeValue(forKey: "busy")
      self.queueCount = UInt(Int(self.queueCount) + delta)
      self.didChangeValue(forKey: "busy")
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
          self.executeTask(block)
        }
      }
    }
    else {
      self.executeTask(block)
    }
  }
  
  func wait()
  {
    let semaphore = DispatchSemaphore(value: 0)
    
    queue.async {
      semaphore.signal()
    }
    semaphore.wait()
  }
  
  func shutDown()
  {
    isShutDown = true
  }
}
