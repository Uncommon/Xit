import Foundation

@resultBuilder
struct MenuBuilder
{
  static func buildExpression(_ expression: NSMenuItem) -> [NSMenuItem]
  {
    [expression]
  }

  static func buildBlock(_ components: [NSMenuItem]...) -> [NSMenuItem]
  {
    components.flatMap { $0 }
  }


  static func buildOptional(_ component: [NSMenuItem]?) -> [NSMenuItem]
  { component ?? [] }

  static func buildEither(first: [NSMenuItem]) -> [NSMenuItem]
  { first }
  static func buildEither(second: [NSMenuItem]) -> [NSMenuItem]
  { second }

  static func buildArray(_ items: [[NSMenuItem]]) -> [NSMenuItem]
  { items.flatMap { $0 } }
}

extension NSMenu
{
  convenience init(title: String = "",
                   @MenuBuilder _ builder: () -> [NSMenuItem])
  {
    self.init(title: title)

    items = builder()
  }
}

extension NSMenuItem
{
  typealias ActionBlock = (NSMenuItem) -> Void

  convenience init(_ title: String,
                   keyEquivalent: String = "",
                   _ block: @escaping ActionBlock)
  {
    self.init(title: title,
              action: #selector(GlobalTarget.shared.action(_:)),
              keyEquivalent: keyEquivalent)

    target = GlobalTarget.shared
    representedObject = block
  }

  convenience init(_ titleString: UIString,
                   keyEquivalent: String = "",
                   _ block: @escaping ActionBlock)
  {
    self.init(titleString.rawValue, keyEquivalent: keyEquivalent, block)
  }

  class GlobalTarget: NSObject
  {
    static let shared = GlobalTarget()

    @objc
    func action(_ item: NSMenuItem)
    {
      (item.representedObject as? ActionBlock)?(item)
    }
  }
}
