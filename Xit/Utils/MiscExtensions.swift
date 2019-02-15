import Foundation

extension NSColor
{
  var invertingBrightness: NSColor
  {
    return NSColor(deviceHue: hueComponent,
                   saturation: saturationComponent,
                   brightness: 1.0 - brightnessComponent,
                   alpha: alphaComponent)
  }

  var cssHSL: String
  {
    let converted = usingColorSpace(.deviceRGB)!
    let hue = converted.hueComponent
    let sat = converted.saturationComponent
    let brightness = converted.brightnessComponent
    
    return "hsl(\(hue*360.0), \(sat*100.0)%, \(brightness*100.0)%)"
  }
  
  var cssRGB: String
  {
    let converted = usingColorSpace(.deviceRGB)!
    let red = converted.redComponent
    let green = converted.greenComponent
    let blue = converted.blueComponent
    
    return "rgb(\(Int(red*255)), \(Int(green*255)), \(Int(blue*255)))"
  }
  
  func withHue(_ hue: CGFloat) -> NSColor
  {
    guard let converted = usingColorSpace(.deviceRGB)
    else { return self }

    return NSColor(deviceHue: hue,
                   saturation: converted.saturationComponent,
                   brightness: converted.brightnessComponent,
                   alpha: converted.alphaComponent)
  }
}

extension NSError
{
  var gitError: git_error_code
  {
    return git_error_code(Int32(code))
  }
  
  convenience init(osStatus: OSStatus)
  {
    self.init(domain: NSOSStatusErrorDomain, code: Int(osStatus), userInfo: nil)
  }
}

extension XMLElement
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

extension NSTreeNode
{
  /// Inserts a child node in sorted order based on the given key extractor
  func insert<T>(node: NSTreeNode, sortedBy extractor: (NSTreeNode) -> T?)
    where T: Comparable
  {
    guard let children = self.children,
          let key = extractor(node)
    else {
      mutableChildren.add(node)
      return
    }
    
    for (index, child) in children.enumerated() {
      guard let childKey = extractor(child)
      else { continue }
      
      if childKey > key {
        mutableChildren.insert(node, at: index)
        return
      }
    }
    mutableChildren.add(node)
  }

  func dump(_ level: Int = 0)
  {
    if let myObject = representedObject as? CustomStringConvertible {
      print(String(repeating: "  ", count: level) + myObject.description)
    }
    
    guard let children = self.children
    else { return }
    
    for child in children {
      child.dump(level + 1)
    }
  }
}

extension Array
{
  /// Returns the number of elements satisfying the predicate.
  func count(where predicate: (Element) -> Bool) -> Int
  {
    return reduce(0) {
      (count, element) -> Int in
      return predicate(element) ? count + 1 : count
    }
  }

  /// Assuming the array is sorted, returns the insertion index for the given
  /// item to be inserted in order.
  func sortedInsertionIndex(of elem: Element,
                            isOrderedBefore: (Element, Element) -> Bool)
                            -> Int
  {
    var lo = 0
    var hi = self.count - 1
    
    while lo <= hi {
      let mid = (lo + hi)/2
      
      if isOrderedBefore(self[mid], elem) {
        lo = mid + 1
      }
      else if isOrderedBefore(elem, self[mid]) {
        hi = mid - 1
      }
      else {
        return mid
      }
    }
    return lo
  }
  
  func objects(at indexSet: IndexSet) -> [Element]
  {
    return indexSet.compactMap { $0 < count ? self[$0] : nil }
  }
  
  mutating func removeObjects(at indexSet: IndexSet)
  {
    self = enumerated().filter { !indexSet.contains($0.offset) }
                       .map { $0.element }
  }
  
  /// Returns the first non-nil result of calling `predicate` on the array's
  /// elements.
  func firstResult<T>(_ predicate: (Element) -> T?) -> T?
  {
    return lazy.compactMap(predicate).first
  }

  func firstOfType<T>() -> T?
  {
    return firstResult { $0 as? T }
  }
}

extension Array where Element: Comparable
{
  mutating func insertSorted(_ newElement: Element)
  {
    insert(newElement,
           at: sortedInsertionIndex(of: newElement) { $0 < $1 })
  }
}

extension NSMutableArray
{
  func sort(keyPath key: String, ascending: Bool = true)
  {
    self.sort(using: [NSSortDescriptor(key: key, ascending: ascending)])
  }
}

extension Thread
{
  /// Performs the block immediately if this is the main thread, or
  /// asynchronosly on the main thread otherwise.
  static func performOnMainThread(_ block: @escaping () -> Void)
  {
    if isMainThread {
      block()
    }
    else {
      DispatchQueue.main.async(execute: block)
    }
  }
  
  /// Performs the block immediately if this is the main thread, or
  /// synchronosly on the main thread otherwise.
  static func syncOnMainThread<T>(_ block: () throws -> T) rethrows -> T
  {
    return isMainThread ? try block()
                        : try DispatchQueue.main.sync(execute: block)
  }
}

extension DecodingError
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
    }
  }
}

/// Similar to Objective-C's `@synchronized`
/// - parameter object: Token object for the lock
/// - parameter block: Block to execute inside the lock
func synchronized<T>(_ object: NSObject, block: () throws -> T) rethrows -> T
{
  objc_sync_enter(object)
  defer {
    objc_sync_exit(object)
  }
  return try block()
}

// Swift 3 took away ++, but it still can be useful.
postfix operator ++

extension UInt
{
  static postfix func ++ (i: inout UInt) -> UInt
  {
    let result = i
    i += 1
    return result
  }
}

infix operator <~

extension String
{
  static func <~ (a: String, b: String) -> Bool
  {
    return a.localizedStandardCompare(b) == .orderedAscending
  }
}

// Reportedly this is hidden in the Swift runtime
// https://oleb.net/blog/2016/10/swift-array-of-c-strings/
public func withArrayOfCStrings<R>(
    _ args: [String],
    _ body: ([UnsafeMutablePointer<CChar>?]) -> R) -> R
{
  let argsCounts = Array(args.map { $0.utf8.count + 1 })
  let argsOffsets = [ 0 ] + scan(argsCounts, 0, +)
  let argsBufferSize = argsOffsets.last!
  
  var argsBuffer: [UInt8] = []
  argsBuffer.reserveCapacity(argsBufferSize)
  for arg in args {
    argsBuffer.append(contentsOf: arg.utf8)
    argsBuffer.append(0)
  }
  
  return argsBuffer.withUnsafeMutableBufferPointer {
    (argsBuffer) in
    let ptr = UnsafeMutableRawPointer(argsBuffer.baseAddress!).bindMemory(
              to: CChar.self, capacity: argsBuffer.count)
    var cStrings: [UnsafeMutablePointer<CChar>?] = argsOffsets.map { ptr + $0 }
    cStrings[cStrings.count-1] = nil
    return body(cStrings)
  }
}

// from SwiftPrivate
public func scan<S: Sequence, U>(
    _ seq: S,
    _ initial: U,
    _ combine: (U, S.Iterator.Element) -> U) -> [U]
{
  var result: [U] = []
  var runningResult = initial
  
  result.reserveCapacity(seq.underestimatedCount)
  for element in seq {
    runningResult = combine(runningResult, element)
    result.append(runningResult)
  }
  return result
}
