import SwiftUI
import XitGit

extension Binding
{
  /// Creates a `Binding` that converts a `String` to a `XitGit.LowerCaseString`.
  static func lowerCaseString<Root: AnyObject>(
    _ root: Root,
    _ keyPath: ReferenceWritableKeyPath<Root, XitGit.LowerCaseString>) -> Binding<String>
  {
    .init {
      root[keyPath: keyPath].rawValue
    } set: {
      root[keyPath: keyPath] = .init($0)
    }
  }
}
