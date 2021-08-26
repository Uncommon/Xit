import Foundation
import Combine

extension Publisher where Self.Failure == Never
{
  /// Convenience function for `receive(on: DispatchQueue.main).sink()`
  public func sinkOnMainQueue(receiveValue: @escaping ((Self.Output) -> Void))
    -> AnyCancellable
  {
    receive(on: DispatchQueue.main)
      .sink(receiveValue: receiveValue)
  }
}
