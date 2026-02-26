import Foundation

public extension RepositoryController
{
  func waitForQueue()
  {
    queue.wait()
    WaitForQueue(DispatchQueue.main)
  }
}
