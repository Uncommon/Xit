import Foundation

protocol UnexpectedTestError: Error {}

/// A condition that isn't supposed to be possible
struct UnreachableError: UnexpectedTestError {}

/// A value unexpectedly failed to convert to another type
struct ConversionFailedError: UnexpectedTestError {}

func testConvert<T, U>(_ value: T) throws -> U
{
  if let result = value as? U {
    return result
  }
  else {
    throw ConversionFailedError()
  }
}
