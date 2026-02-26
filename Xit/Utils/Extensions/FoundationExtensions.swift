import Foundation
import UniformTypeIdentifiers

public extension XMLElement
{
  /// Returns the element's attributes as a dictionary.
  func attributesDict() -> [String: String]
  {
    guard let attributes = attributes
    else { return [:] }

    var result = [String: String]()

    for attribute in attributes {
      guard let name = attribute.name,
            let value = attribute.stringValue
      else { continue }

      result[name] = value
    }
    return result
  }

  /// Returns a list of attribute values of all children, matching the given
  /// attribute name.
  func childrenAttributes(_ name: String) -> [String]
  {
    return children?.compactMap {
      ($0 as? XMLElement)?.attribute(forName: name)?.stringValue
    } ?? []
  }
}

public extension Thread
{
  /// Performs the block immediately if this is the main thread, or
  /// synchronosly on the main thread otherwise.
  static func syncOnMain<T>(_ block: () throws -> T) rethrows -> T
  {
    return isMainThread ? try block()
      : try DispatchQueue.main.sync(execute: block)
  }
}

public extension DecodingError
{
  var context: Context
  {
    switch self {
      case .dataCorrupted(let context):
        return context
      case .keyNotFound(_, let context):
        return context
      case .typeMismatch(_, let context):
        return context
      case .valueNotFound(_, let context):
        return context
      @unknown default:
        return Context(codingPath: [], debugDescription: "")
    }
  }
}

public extension NSObject
{
  func withSync<T>(block: () throws -> T) rethrows -> T
  {
    objc_sync_enter(self)
    defer {
      objc_sync_exit(self)
    }
    return try block()
  }
}

public extension TimeInterval
{
  static let minutes: TimeInterval = 60
}

public extension UTType
{
  /// Returns the type for the given extension, or `.item` if none found.
  static func fromExtension(_ ext: String) -> UTType
  {
    .init(filenameExtension: ext) ?? .item
  }
}

// Swift 3 took away ++, but it still can be useful.
postfix operator ++

public extension Strideable where Stride == Int
{
  static postfix func ++ (i: inout Self) -> Self
  {
    let result = i
    i = i.advanced(by: 1)
    return result
  }
}

public extension Timer
{
  static func mainScheduledTimer(
    withTimeInterval interval: TimeInterval,
    repeats: Bool,
    block: @escaping @Sendable @MainActor (Timer) -> Void
  ) -> Timer
  {
    let timer = Timer(timeInterval: interval, repeats: repeats) {
      timer in
      MainActor.assumeIsolated { block(timer) }
    }

    RunLoop.main.add(timer, forMode: .default)
    return timer
  }
}
