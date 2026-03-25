import Foundation

public extension Data
{
  init?(immutableBytesNoCopy bytes: UnsafeRawPointer, count: Int,
        deallocator: Deallocator)
  {
    guard let cfData = CFDataCreateWithBytesNoCopy(
      kCFAllocatorDefault,
      bytes.assumingMemoryBound(to: UInt8.self),
      count,
      deallocator.cfAllocator)
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
