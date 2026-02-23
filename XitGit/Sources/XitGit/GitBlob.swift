import Foundation
import Clibgit2
import FakedMacro

@Faked
public protocol Blob: ContiguousBytes
{
  var dataSize: UInt { get }
  var isBinary: Bool { get }

  func makeData() -> Data?
  
  // For ContiguousBytes
  @FakeDefault(exp: "try body(.init(start: nil, count: 0))")
  func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R)
      rethrows -> R
}

public final class GitBlob
{
  let blob: OpaquePointer

  init(blob: OpaquePointer)
  {
    self.blob = blob
  }
  
  init?(repository: OpaquePointer, oid: GitOID)
  {
    guard let blob = try? OpaquePointer.from({
      (blob) in
      oid.withUnsafeOID { git_blob_lookup(&blob, repository, $0) }
    })
    else { return nil }
    
    self.blob = blob
  }

  deinit
  {
    git_blob_free(blob)
  }
}

extension GitBlob: Blob
{
  public var dataSize: UInt
  { UInt(git_blob_rawsize(blob)) }

  public var isBinary: Bool
  { git_blob_is_binary(blob) != 0 }

  // for ContiguousBytes
  public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R)
    rethrows -> R
  {
    try body(.init(start: git_blob_rawcontent(blob),
                   count: Int(git_blob_rawsize(blob))))
  }

  public func makeData() -> Data?
  {
    return Data(bytes: git_blob_rawcontent(blob),
                count: Int(git_blob_rawsize(blob)))
  }
}

extension GitBlob: OIDObject
{
  public var id: GitOID
  { GitOID(oidPtr: git_blob_id(blob)) }
}
