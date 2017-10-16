import Foundation

public protocol DiffDelta
{
  var deltaStatus: DeltaStatus { get }
  var diffFlags: DiffFlags { get }
  var oldFile: DiffFile { get }
  var newFile: DiffFile { get }
}

typealias GitDiffDelta = git_diff_delta

extension git_diff_delta
{
  // Apparently you can't declare a function with @convention(c)
  // (something to do with name mangling?) so this has to be a block
  static let fileCallback: git_diff_file_cb = {
    (delta, progress, payload) in
    guard let delta = delta
    else { return GIT_ERROR.rawValue }
    let target = payload!.bindMemory(to: git_diff_delta.self, capacity: 1)
    
    target.assign(from: delta, count: 1)
    return GIT_OK.rawValue
  }
  
  init?(oldBlob: Blob, newBlob: Blob)
  {
    guard let oldGitBlob = oldBlob as? GitBlob,
          let newGitBlob = newBlob as? GitBlob
    else { return nil }
    
    // Must be initialized before taking its address
    self = git_diff_delta()
    
    let result = git_diff_blobs(
          oldGitBlob.blob, nil, newGitBlob.blob, nil, nil,
          git_diff_delta.fileCallback, nil, nil, nil, &self)
    guard result == 0
    else { return nil }
  }
  
  init?(oldBlob: Blob, newData: Data)
  {
    guard let oldGitBlob = oldBlob as? GitBlob
    else { return nil }
    
    self = git_diff_delta()
    
    var result: Int32 = 0
    
    newData.withUnsafeBytes {
      (bytes) in
      result = git_diff_blob_to_buffer(oldGitBlob.blob, nil,
                                       bytes, newData.count, nil, nil,
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
      (oldBytes) in
      newData.withUnsafeBytes {
        (newBytes) in
        result = git_diff_buffers(oldBytes, oldData.count, nil,
                                  newBytes, newData.count, nil, nil,
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
  public var deltaStatus: DeltaStatus { return DeltaStatus(gitDelta: status) }
  public var diffFlags: DiffFlags { return DiffFlags(rawValue: flags) }
  public var oldFile: DiffFile { return old_file }
  public var newFile: DiffFile { return new_file }
}
