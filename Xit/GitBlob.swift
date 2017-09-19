import Foundation

public protocol Blob
{
  var dataSize: UInt { get }
  
  /// Consumers should use `withData` instead, since the buffer may have a
  /// limited lifespan.
  func makeData() -> Data?
}

extension Blob
{
  /// Calls `callback` with a data object, or throws `BlobError.cantLoadData`
  /// if the data can't be loaded.
  public func withData(callback: (Data) throws -> Void) throws
  {
    guard let data = makeData()
    else { throw BlobError.cantLoadData }
    
    try callback(data)
  }
}

enum BlobError: Swift.Error
{
  case cantLoadData
}

public class GitBlob: Blob
{
  let blob: OpaquePointer
  
  init?(repository: XTRepository, oid: OID)
  {
    guard let oid = oid as? GitOID
    else { return nil }
    var blob: OpaquePointer?
    let result = git_blob_lookup(&blob, repository.gtRepo.git_repository(),
                                 oid.unsafeOID())
    guard result == 0,
          let finalBlob = blob
    else { return nil }
    
    self.blob = finalBlob
  }
  
  public var dataSize: UInt
  {
    return UInt(git_blob_rawsize(blob))
  }
  
  public func makeData() -> Data?
  {
    // TODO: Fix the immutableBytes costructor to avoid unneeded copying
    return Data(bytes: git_blob_rawcontent(blob),
                count: Int(git_blob_rawsize(blob)))
  }
  
  func makeGTBlob() -> GTBlob?
  {
    guard let gtRepo = GTRepository(gitRepository: git_blob_owner(blob))
    else { return nil }
    
    return GTBlob(obj: blob, in: gtRepo)
  }
  
  deinit
  {
    git_blob_free(blob)
  }
}

extension GTBlob: Blob
{
  public var dataSize: UInt { return UInt(size()) }

  public func makeData() -> Data? { return data() }
}

extension Data
{
  // There is no Data constructor that treats the buffer as immutable
  init?(immutableBytes: UnsafeRawPointer, count: Int)
  {
    guard let data = CFDataCreateWithBytesNoCopy(
        kCFAllocatorDefault, immutableBytes.assumingMemoryBound(to: UInt8.self),
        count, kCFAllocatorNull)
    else { return nil }
    
    self.init(referencing: data as NSData)
  }
}
