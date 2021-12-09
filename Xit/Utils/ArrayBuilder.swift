import Foundation

/// Provides a base implementation for result builders that generate arrays.
protocol ArrayBuilder
{
  associatedtype Element
}

extension ArrayBuilder
{
  static func buildExpression(_ expression: Element) -> [Element]
  { [expression] }
  static func buildExpression(_ expression: [Element]) -> [Element]
  { expression }

  static func buildBlock(_ components: [Element]...) -> [Element]
  { components.flatMap { $0 } }


  static func buildOptional(_ component: [Element]?) -> [Element]
  { component ?? [] }

  static func buildEither(first: [Element]) -> [Element]
  { first }
  static func buildEither(second: [Element]) -> [Element]
  { second }

  static func buildArray(_ items: [[Element]]) -> [Element]
  { items.flatMap { $0 } }
}
