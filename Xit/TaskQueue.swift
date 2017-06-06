import Foundation

class TaskQueue: NSObject
{
  let queue: DispatchQueue
  let group = DispatchGroup()
  var queueCount: UInt = 0
  fileprivate(set) var isShutDown = false
  fileprivate(set) var isWriting = false
  
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
        queue.async(group: group) {
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
    group.wait()
  }
  
  func shutDown()
  {
    isShutDown = true
  }
}
