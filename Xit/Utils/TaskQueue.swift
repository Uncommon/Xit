import Foundation

class TaskQueue: NSObject
{
  @objc let queue: DispatchQueue
  let group = DispatchGroup()
  var queueCount: UInt = 0
  fileprivate(set) var isShutDown = false
  
  @objc var busy: Bool
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
      [weak self] in
      guard let self = self
      else { return }
      
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
  
  @objc
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
  
  @objc
  func wait()
  {
    let semaphore = DispatchSemaphore(value: 0)
    
    queue.async {
      semaphore.signal()
    }
    semaphore.wait()
  }
  
  @objc
  func shutDown()
  {
    isShutDown = true
  }
}
