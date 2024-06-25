import Foundation

// The choice of these convenience operators is somewhat arbitrary, and is
// restricted to symbols that are a) legal operators in Swift and
// b) easy to type.
prefix operator ◊ // shift-opt-v
prefix operator ¶ // opt-7

/// Creates an instance of a `RawRepresentable` string type, such as
/// `NSBindingName`, from a string literal.
prefix func ◊<T>(string: StringLiteralType) -> T
  where T: RawRepresentable, T.RawValue == String
{
  return T(rawValue: string)!
}

/// Creates an `NSUserInterfaceItemIdentifier` from a string literal. Useful in
/// cases where ◊ would still require specifying the type.
prefix func ¶(string: StringLiteralType) -> NSUserInterfaceItemIdentifier
{
  return NSUserInterfaceItemIdentifier(rawValue: string)
}
