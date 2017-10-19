import Foundation

public protocol Blob
{
  var dataSize: UInt { get }
  var blobPtr: OpaquePointer? { get }
  
  /// Consumers should use `withData` instead, since the buffer may have a
  /// limited lifespan.
  func makeData() -> Data?
}

extension Blob
{
  /// Calls `callback` with a data object, or throws `BlobError.cantLoadData`
  /// if the data can't be loaded.
  public func withData<T>(_ callback: (Data) throws -> T) throws -> T
  {
    guard let data = makeData()
    else { throw BlobError.cantLoadData }
    
    return try callback(data)
  }
}

enum BlobError: Swift.Error
{
  case cantLoadData
}

public class GitBlob: Blob, OIDObject
{
  let blob: OpaquePointer
  
  public var oid: OID
  {
    return GitOID(oidPtr: git_blob_id(blob))
  }
  
  init(blob: OpaquePointer)
  {
    self.blob = blob
  }
  
  convenience init?(repository: XTRepository, oid: OID)
  {
    self.init(gitRepository: repository.gtRepo.git_repository(), oid: oid)
  }
  
  init?(gitRepository: OpaquePointer, oid: OID)
  {
    guard let oid = oid as? GitOID
    else { return nil }
    var blob: OpaquePointer?
    let result = git_blob_lookup(&blob, gitRepository, oid.unsafeOID())
    guard result == 0,
          let finalBlob = blob
    else { return nil }
    
    self.blob = finalBlob
  }
  
  public var blobPtr: OpaquePointer? { return blob }
  
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
  public var blobPtr: OpaquePointer? { return git_blob() }

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
