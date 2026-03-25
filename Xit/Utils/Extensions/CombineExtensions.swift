import Foundation
import Combine

public extension Publisher
{
  /// For each published element, `object`'s `keyPath` is set to `nil`, and then
  /// a `debounce` is applied on the main queue.
  func debounce<T, O>(
    afterInvalidating object: T,
    keyPath: ReferenceWritableKeyPath<T, O?>,
    delay: DispatchQueue.SchedulerTimeType.Stride = 0.25)
    -> Publishers.Debounce<Publishers.HandleEvents<Self>, DispatchQueue>
    where T: AnyObject
  {
    return handleEvents(receiveOutput: { _ in
      object[keyPath: keyPath] = nil
    }).debounce(for: delay, scheduler: DispatchQueue.main)
  }
}

public extension Publisher where Self.Failure == Never
{
  /// Convenience function for `receive(on: DispatchQueue.main).sink()`
  func sinkOnMainQueue(receiveValue: @escaping (Self.Output) -> Void)
    -> AnyCancellable
  {
    receive(on: DispatchQueue.main)
      .sink(receiveValue: receiveValue)
  }
}
