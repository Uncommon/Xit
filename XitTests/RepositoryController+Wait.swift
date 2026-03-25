import Foundation
@testable import Xit

public extension RepositoryController
{
  func waitForQueue()
  {
    queue.wait()
    WaitForQueue(DispatchQueue.main)
  }
}
