import Foundation

protocol Blob
{
  var size: UInt { get }
  
  func withData(callback: (Data) throws -> Void) rethrows
}

class GitBlob: Blob
{
  let blob: OpaquePointer
  
  init?(repository: XTRepository, oid: GitOID)
  {
    var blob: OpaquePointer?
    let result = git_blob_lookup(&blob, repository.gtRepo.git_repository(),
                                 oid.unsafeOID())
    guard result == 0,
          let finalBlob = blob
    else { return nil }
    
    self.blob = finalBlob
  }
  
  var size: UInt
  {
    return UInt(git_blob_rawsize(blob))
  }
  
  private func makeData() -> Data
  {
    return Data(immutableBytes: git_blob_rawcontent(blob),
                count: Int(git_blob_rawsize(blob)))
           ?? Data()
  }
  
  /// Calls the given callback with a Data object containing the blob's data.
  /// The pointer provided by libgit2 does not have a guaranteed lifetime.
  func withData(callback: (Data) throws -> Void) rethrows
  {
    let data = makeData()
    
    try callback(data)
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
