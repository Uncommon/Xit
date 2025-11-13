import Foundation
import Siesta

enum ServiceError: Swift.Error
{
  case unexpected
  case canceled
}

extension Siesta.Resource
{
  /// Either executes the closure with the resource's data, or schedules it
  /// to run later when the data is available.
  func useData(owner: AnyObject, closure: @escaping (Siesta.Entity<Any>) -> Void)
  {
    if isUpToDate, let data = latestData {
      closure(data)
    }
    else {
      addObserver(owner: owner) {
        (resource, event) in
        if case .newData = event,
           let data = resource.latestData {
          closure(data)
        }
      }
      loadIfNeeded()
    }
  }

  /// Returns the latest data, or waits for data to arrive.
  var data: Entity<Any>
  {
    @MainActor
    get async throws
    {
      if isUpToDate, let data = latestData {
        return data
      }
      else {
        return try await withCheckedThrowingContinuation { continuation in
          // Convenience functions to help make sure we always remove
          // to avoid multiple resume calls
          func resume(returning result: Entity<Any>)
          {
            self.removeObservers(ownedBy: self)
            continuation.resume(returning: result)
          }
          func resume<T>(throwing error: T) where T: Error
          {
            self.removeObservers(ownedBy: self)
            continuation.resume(throwing: error)
          }
          addObserver(owner: self) {
            (resource, event) in
            switch event {
              case .newData:
                if let data = resource.latestData {
                  resume(returning: data)
                  return
                }
              case .error:
                if let error = resource.latestError {
                  resume(throwing: error)
                  return
                }
              case .notModified, .observerAdded, .requested:
                return
              case .requestCancelled:
                resume(throwing: ServiceError.canceled)
                return
            }
            resume(throwing: ServiceError.unexpected)
          }
          DispatchQueue.main.async {
            self.loadIfNeeded()
          }
        }
      }
    }
  }
}

extension Siesta.Request
{
  @MainActor
  func complete() async throws
  {
    try await withCheckedThrowingContinuation {
      (continuation: CheckedContinuation<Void, Error>) in
      onCompletion {
        (info) in
        switch info.response {
          case .success:
            continuation.resume()
          case .failure(let error):
            continuation.resume(throwing: error)
        }
      }
    }
  }
}
