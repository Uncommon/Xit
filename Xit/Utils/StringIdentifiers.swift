import Foundation

prefix operator ◊
prefix operator ¶

// This allows the ◊ operater to serve as a shortcut for creating instances of
// NSImage.Name, Notification.Name, etc. with ◊"identifier"
prefix func ◊<T>(string: StringLiteralType) -> T
  where T: RawRepresentable, T.RawValue == String
{
  return T(rawValue: string)!
}

// NSUserInterfaceItemIdentifier is often used in cases where there isn't enough
// context to use ◊ without alse specifying a type. "¶" was chosen because it
// sort of looks like "id" and it's easy to type (option-7).
prefix func ¶(string: String) -> NSUserInterfaceItemIdentifier
{
  return NSUserInterfaceItemIdentifier(rawValue: string)
}
