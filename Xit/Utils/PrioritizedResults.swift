import Foundation

/// A collection of results evaluated in prority order, as defined by the order
/// of cases in `E`.
@dynamicMemberLookup
struct ProritizedResults<E>
  where E: CaseIterable & RawRepresentable & Hashable, E.RawValue == String
{
  var results: [E: any AbstractResult] = [:]
  
  /// Evaluates the results in order, and returns the first error found provided
  /// all previous results were successful.
  var firstError: (any Error)?
  {
    for item in E.allCases {
      if let result = results[item] {
        if let error = result.error {
          return error
        }
        // otherwise it was a success, so continue with the next result
      }
    }
    return nil
  }
  
  var allSucceeded: Bool
  { E.allCases.allSatisfy { results[$0]?.succeeded ?? false } }
  
  /// Enables getting and setting results via `myResults.enumCase`. This is the
  /// reason for requiring `E.RawValue == String`.
  /// - Note: Ideally, this would take a keypath for the enum, but that would
  /// require static keypaths which are not currently supported in Swift.
  subscript(dynamicMember name: String) -> (any AbstractResult)?
  {
    get { E(rawValue: name).flatMap { results[$0] } }
    set { E(rawValue: name).map { results[$0] = newValue } }
  }
}

/// Since `Result` is generic, a base type is needed to aggregate results.
protocol AbstractResult
{
  var succeeded: Bool { get }
  var error: (any Error)? { get }
}

extension Result: AbstractResult
{
  var succeeded: Bool
  {
    switch self {
      case .success: return true
      case .failure: return false
    }
  }
  
  var error: (any Error)?
  {
    switch self {
      case .success: return nil
      case .failure(let error): return error
    }
  }
}
