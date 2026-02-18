import Foundation

public extension Data
{
  init?(immutableBytesNoCopy bytes: UnsafeRawPointer, count: Int,
        deallocator: Deallocator)
  {
    guard let cfData = CFDataCreateWithBytesNoCopy(
      kCFAllocatorDefault, bytes.assumingMemoryBound(to: UInt8.self),
      count, deallocator.cfAllocator)
    else { return nil }

    self.init(referencing: cfData)
  }
}

public extension Data.Deallocator
{
  var cfAllocator: CFAllocator
  {
    switch self {
      case .virtualMemory, .unmap, .custom:
        preconditionFailure("not implemented")
      case .free:
        return kCFAllocatorMalloc
      case .none:
        return kCFAllocatorNull
      @unknown default:
        return kCFAllocatorNull
    }
  }
}

public extension URL
{
  /// Returns a copy of the URL with its path replaced
  func withPath(_ path: String) -> URL
  {
    guard var components = URLComponents(url: self,
                                         resolvingAgainstBaseURL: false)
    else { return self }
    
    components.path = path
    return components.url ?? self
  }
  
  /// Returns the default port based on the URL's scheme
  var defaultPort: Int
  {
    switch scheme {
      case "https":
        return 443
      case "ssh":
        return 22
      case "git":
        return 9418
      default:
        return 80
    }
  }
}

public extension Array
{
  /// Assuming the array is sorted, returns the insertion index for the given
  /// item to be inserted in order.
  func sortedInsertionIndex(of elem: Element,
                            isOrderedBefore: (Element, Element) -> Bool)
                            -> Int
  {
    var lo = startIndex
    var hi = index(before: endIndex)
    
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
  
  /// Returns the first non-nil result of calling `predicate` on the array's
  /// elements.
  func firstResult<T>(_ predicate: (Element) -> T?) -> T?
  {
    // We're not "actually escaping" because we immediately use and discard
    // the result of `compactMap`.
    return withoutActuallyEscaping(predicate) { lazy.compactMap($0).first }
  }
}

public extension Array where Element: Comparable
{
  mutating func insertSorted(_ newElement: Element)
  {
    insert(newElement,
           at: sortedInsertionIndex(of: newElement) { $0 < $1 })
  }
}

// Same as `withArrayOfCStrings()` but the callback has an inout parameter
public func withMutableArrayOfCStrings<R>(
    _ args: [String],
    _ body: (inout [UnsafeMutablePointer<CChar>?]) -> R) -> R
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
    return body(&cStrings)
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
