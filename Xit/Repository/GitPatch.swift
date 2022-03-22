import Foundation

public protocol Patch
{
  var hunkCount: Int { get }
  var addedLinesCount: Int { get }
  var deletedLinesCount: Int { get }

  func hunk(at index: Int) -> (any DiffHunk)?
}


final class GitPatch: Patch
{
  let patch: OpaquePointer // git_patch
  
  // Data buffers need to be kept because the patch references them
  let oldData, newData: Data?
  
  init(gitPatch: OpaquePointer)
  {
    self.patch = gitPatch
    self.oldData = nil
    self.newData = nil
  }
  
  init?(oldBlob: any Blob, newBlob: any Blob, options: DiffOptions? = nil)
  {
    guard let oldGitBlob = (oldBlob as? GitBlob)?.blob,
          let newGitBlob = (newBlob as? GitBlob)?.blob,
          let patch = try? OpaquePointer.from({
            (patch) in
            GitDiff.unwrappingOptions(options) {
              git_patch_from_blobs(&patch, oldGitBlob, nil,
                                   newGitBlob, nil, $0)
            }
          })
    else { return nil }
    
    self.patch = patch
    self.oldData = nil
    self.newData = nil
  }
  
  init?(oldBlob: any Blob, newData: Data, options: DiffOptions? = nil)
  {
    guard let oldGitBlob = (oldBlob as? GitBlob)?.blob,
          let patch = try? OpaquePointer.from({
            (patch) in
            GitDiff.unwrappingOptions(options) {
              (gitOptions) in
              newData.withUnsafeBytes {
                (bytes: UnsafeRawBufferPointer) in
                git_patch_from_blob_and_buffer(
                    &patch, oldGitBlob, nil,
                    bytes.bindMemory(to: Int8.self).baseAddress,
                    newData.count, nil,
                    gitOptions)
              }
            }
          })
    else { return nil }
    
    self.patch = patch
    self.oldData = nil
    self.newData = newData
  }
  
  init?(oldData: Data, newData: Data, options: DiffOptions? = nil)
  {
    guard let patch = try? OpaquePointer.from({
      (patch) in
      GitDiff.unwrappingOptions(options) {
        (gitOptions) in
        oldData.withUnsafeBytes {
          (oldBytes: UnsafeRawBufferPointer) in
          newData.withUnsafeBytes {
            (newBytes: UnsafeRawBufferPointer) in
            git_patch_from_buffers(&patch,
                                   oldBytes.baseAddress, oldData.count, nil,
                                   newBytes.baseAddress, newData.count, nil,
                                   gitOptions)
          }
        }
      }
    })
    else { return nil }
    
    self.patch = patch
    self.oldData = oldData
    self.newData = newData
  }
  
  var hunkCount: Int { git_patch_num_hunks(patch) }
  var addedLinesCount: Int
  {
    var result: Int = 0
    
    _ = git_patch_line_stats(nil, &result, nil, patch)
    return result
  }
  var deletedLinesCount: Int
  {
    var result: Int = 0
    
    _ = git_patch_line_stats(nil, nil, &result, patch)
    return result
  }

  func hunk(at index: Int) -> DiffHunk?
  {
    guard let hunk: UnsafePointer<git_diff_hunk> = try? .from({
      git_patch_get_hunk(&$0, nil, patch, index)
    })
    else { return nil }
    
    return GitDiffHunk(hunk: hunk.pointee, index: index, patch: self)
  }
}
