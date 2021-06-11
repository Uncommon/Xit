import Foundation

/// A collection of results evaluated in prority order, as defined by the order
/// of cases in `E`.
@dynamicMemberLookup
struct ProritizedResults<E>
  where E: CaseIterable & RawRepresentable & Hashable, E.RawValue == String
{
  var results: [E: AbstractResult] = [:]
  
  /// Evaluates the results in order, and returns the first error found provided
  /// all previous results were successful.
  var firstError: Error?
  {
    for item in E.allCases {
      if let result = results[item] {
        if let error = result.error {
          return error
        }
        // otherwise it was a success, so continue with the next result
      }
      else {
        return nil
      }
    }
    return nil
  }
  
  var allSucceeded: Bool
  { E.allCases.allSatisfy { results[$0]?.succeeded ?? false } }
  
  /// Enables getting and setting results via `myResults.enumCase`. This is the
  /// reason for requiring `E.RawValue == String`.
  subscript(dynamicMember name: String) -> AbstractResult?
  {
    get { E(rawValue: name).flatMap { results[$0] } }
    set { E(rawValue: name).map { results[$0] = newValue } }
  }
}

/// Since `Result` is generic, a base type is needed to aggregate results.
protocol AbstractResult
{
  var succeeded: Bool { get }
  var error: Error? { get }
}

extension Result: AbstractResult
{
  var succeeded: Bool
  {
    switch self {
      case .success(_): return true
      case .failure(_): return false
    }
  }
  
  var error: Error?
  {
    switch self {
      case .success(_): return nil
      case .failure(let error): return error
    }
  }
}
