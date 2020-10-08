import Foundation

protocol UnexpectedTestError: Error {}

struct ConversionFailedError: UnexpectedTestError
{
}

func testConvert<T, U>(_ value: T) throws -> U
{
  if let result = value as? U {
    return result
  }
  else {
    throw ConversionFailedError()
  }
}
