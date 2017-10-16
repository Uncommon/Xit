import Foundation

public protocol Patch
{
  var hunkCount: Int { get }
  var addedLinesCount: Int { get }
  var deletedLinesCount: Int { get }

  func hunk(at index: Int) -> DiffHunk?
}


class GitPatch: Patch
{
  let patch: OpaquePointer // git_patch
  
  init(gitPatch: OpaquePointer)
  {
    self.patch = gitPatch
  }
  
  init?(oldBlob: Blob, newBlob: Blob, options: DiffOptions? = nil)
  {
    guard let oldGitBlob = oldBlob.blobPtr,
          let newGitBlob = newBlob.blobPtr
    else { return nil }
    var patch: OpaquePointer?
    let result: Int32 = GitDiff.unwrappingOptions(options) {
      return git_patch_from_blobs(&patch, oldGitBlob, nil,
                                  newGitBlob, nil, $0)
    }
    guard result == 0,
          let finalPatch = patch
    else { return nil }
    
    self.patch = finalPatch
  }
  
  init?(oldBlob: Blob, newData: Data, options: DiffOptions? = nil)
  {
    guard let oldGitBlob = oldBlob.blobPtr
    else { return nil }
    var patch: OpaquePointer?
    let result: Int32 = GitDiff.unwrappingOptions(options) {
      (gitOptions) in
      return newData.withUnsafeBytes {
        (bytes) in
        return git_patch_from_blob_and_buffer(&patch, oldGitBlob, nil,
                                              bytes, newData.count, nil,
                                              gitOptions)
      }
    }
    guard result == 0,
          let finalPatch = patch
    else { return nil }
    
    self.patch = finalPatch
  }
  
  init?(oldData: Data, newData: Data, options: DiffOptions? = nil)
  {
    var patch: OpaquePointer?
    let result: Int32 = GitDiff.unwrappingOptions(options) {
      (gitOptions) in
      return oldData.withUnsafeBytes {
        (oldBytes) in
        return newData.withUnsafeBytes {
          (newBytes) in
          return git_patch_from_buffers(&patch,
                                        oldBytes, oldData.count, nil,
                                        newBytes, newData.count, nil,
                                        gitOptions)
        }
      }
    }
    guard result == 0,
          let finalPatch = patch
    else { return nil }
    
    self.patch = finalPatch
  }
  
  var hunkCount: Int { return git_patch_num_hunks(patch) }
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
    let hunk = UnsafeMutablePointer<UnsafePointer<git_diff_hunk>?>
               .allocate(capacity: 1)
    let result = git_patch_get_hunk(hunk, nil, patch, index)
    guard result == 0,
          let finalHunk = hunk.pointee?.pointee
    else { return nil }
    
    return GitDiffHunk(hunk: finalHunk, index: index, patch: self)
  }
}
