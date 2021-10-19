import Foundation

public protocol Blob
{
  var dataSize: UInt { get }
  var blobPtr: OpaquePointer? { get }
  var isBinary: Bool { get }

  /// Calls `callback` with a data object, or throws `BlobError.cantLoadData`
  /// if the data can't be loaded.
  func withData<T>(_ callback: (Data) throws -> T) throws -> T

  /// Consumers should use `withData` instead, since the buffer may have a
  /// limited lifespan.
  func makeData() -> Data?
}

extension Blob
{
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

public final class GitBlob: Blob, OIDObject
{
  let blob: OpaquePointer
  
  public var oid: OID
  { GitOID(oidPtr: git_blob_id(blob)) }
  
  init(blob: OpaquePointer)
  {
    self.blob = blob
  }
  
  init?(repository: OpaquePointer, oid: OID)
  {
    guard let oid = oid as? GitOID,
          let blob = try? OpaquePointer.from({
      (blob) in
      oid.withUnsafeOID { git_blob_lookup(&blob, repository, $0) }
    })
    else { return nil }
    
    self.blob = blob
  }
  
  public var blobPtr: OpaquePointer? { blob }
  
  public var dataSize: UInt
  { UInt(git_blob_rawsize(blob)) }
  
  public var isBinary: Bool
  { git_blob_is_binary(blob) != 0 }
  
  public func makeData() -> Data?
  {
    // TODO: Fix the immutableBytes costructor to avoid unneeded copying
    return Data(bytes: git_blob_rawcontent(blob),
                count: Int(git_blob_rawsize(blob)))
  }
  
  deinit
  {
    git_blob_free(blob)
  }
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
