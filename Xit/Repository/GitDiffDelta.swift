import Foundation

public protocol DiffDelta
{
  var deltaStatus: DeltaStatus { get }
  var diffFlags: DiffFlags { get }
  var oldFile: any DiffFile { get }
  var newFile: any DiffFile { get }
}

typealias GitDiffDelta = git_diff_delta

extension git_diff_delta
{
  // Apparently you can't declare a function with @convention(c)
  // (something to do with name mangling?) so this has to be a block
  static let fileCallback: git_diff_file_cb = {
    (delta, _, payload) in
    guard let delta = delta
    else { return GIT_ERROR.rawValue }
    let target = payload!.bindMemory(to: git_diff_delta.self, capacity: 1)
    
    target.update(from: delta, count: 1)
    return GIT_OK.rawValue
  }
  
  init?(oldBlob: any Blob, newBlob: any Blob)
  {
    guard let oldGitBlob = (oldBlob as? GitBlob)?.blob,
          let newGitBlob = (newBlob as? GitBlob)?.blob
    else { return nil }
    
    // Must be initialized before taking its address
    self = git_diff_delta()
    
    let result = git_diff_blobs(
          oldGitBlob, nil, newGitBlob, nil, nil,
          git_diff_delta.fileCallback, nil, nil, nil, &self)
    guard result == 0
    else { return nil }
  }
  
  init?(oldBlob: any Blob, newData: Data)
  {
    guard let oldGitBlob = (oldBlob as? GitBlob)?.blob
    else { return nil }
    
    self = git_diff_delta()
    
    var result: Int32 = 0
    
    newData.withUnsafeBytes {
      (bytes: UnsafeRawBufferPointer) in
      result = git_diff_blob_to_buffer(oldGitBlob, nil,
                                       bytes.bindMemory(to: Int8.self).baseAddress,
                                       newData.count, nil, nil,
                                       git_diff_delta.fileCallback,
                                       nil, nil, nil, &self)
    }
    
    guard result == 0
    else { return nil }
  }
  
  init?(oldData: Data, newData: Data)
  {
    var result: Int32 = 0

    self = git_diff_delta()
    oldData.withUnsafeBytes {
      (oldBytes: UnsafeRawBufferPointer) in
      newData.withUnsafeBytes {
        (newBytes: UnsafeRawBufferPointer) in
        result = git_diff_buffers(oldBytes.baseAddress, oldData.count, nil,
                                  newBytes.baseAddress, newData.count, nil, nil,
                                  git_diff_delta.fileCallback,
                                  nil, nil, nil, &self)
      }
    }
    
    guard result == 0
    else { return nil }
  }
}

extension git_diff_delta: DiffDelta
{
  public var deltaStatus: DeltaStatus { DeltaStatus(gitDelta: status) }
  public var diffFlags: DiffFlags { DiffFlags(rawValue: flags) }
  public var oldFile: DiffFile { old_file }
  public var newFile: DiffFile { new_file }
}
