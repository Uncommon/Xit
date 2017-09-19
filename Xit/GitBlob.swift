import Foundation

public protocol Blob
{
  var size: UInt { get }
  
  func makeData() -> Data
  func withData(callback: (Data) -> Void)
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
  
  public var size: UInt
  {
    return UInt(git_blob_rawsize(blob))
  }
  
  public func makeData() -> Data
  {
    return Data(immutableBytes: git_blob_rawcontent(blob),
                count: Int(git_blob_rawsize(blob)))
           ?? Data()
  }
  
  /// Calls the given callback with a Data object containing the blob's data.
  /// The pointer provided by libgit2 does not have a guaranteed lifetime.
  public func withData(callback: (Data) -> Void)
  {
    let data = makeData()
    
    callback(data)
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

extension Data
{
  // There is no Data constructor that treats the buffer as immutable
  init?(immutableBytes: UnsafeRawPointer, count: Int)
  {
    guard let data = CFDataCreateWithBytesNoCopy(
        kCFAllocatorNull, immutableBytes.assumingMemoryBound(to: UInt8.self),
        count, kCFAllocatorNull)
    else { return nil }
    
    self.init(referencing: data as NSData)
  }
}
