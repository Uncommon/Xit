import Foundation

public protocol Diff: AnyObject
{
  associatedtype Delta: DiffDelta
  associatedtype Patch: Xit.Patch
  associatedtype Stats: DiffStats

  var deltaCount: Int { get }
  
  func delta(at index: Int) -> Delta?
  func patch(at index: Int) -> Patch?

  func stats() -> Stats?
}

public protocol DiffFile<ObjectIdentifier>: OIDObject
{
  associatedtype ObjectIdentifier

  var filePath: String { get }
  var size: UInt64 { get }
  var diffFlags: DiffFlags { get }
}

public protocol DiffLine
{
  var type: DiffLineType { get }
  var oldLine: Int32 { get }
  var newLine: Int32 { get }
  var lineCount: Int32 { get }
  var byteCount: Int { get }
  var offset: Int64 { get }
  var text: String { get }
}

struct DiffDeltas: Collection
{
  let diff: any Diff

  var startIndex: Int { 0 }
  var endIndex: Int { diff.deltaCount }

  subscript(position: Int) -> any DiffDelta { diff.delta(at: position)! }
  func index(after i: Int) -> Int { i + 1 }
}

struct DiffPatches: Collection
{
  let diff: any Diff

  var startIndex: Int { 0 }
  var endIndex: Int { diff.deltaCount }

  subscript(position: Int) -> any Patch { diff.patch(at: position)! }
  func index(after i: Int) -> Int { i + 1 }
}

extension Diff
{
  var deltas: DiffDeltas { .init(diff: self) }
  var patches: DiffPatches { .init(diff: self) }
}

typealias DiffOptions = git_diff_options

extension git_diff_options
{
  init(flags: DiffOptionFlags)
  {
    self = git_diff_options()
    git_diff_init_options(&self, UInt32(GIT_DIFF_OPTIONS_VERSION))
    self.flags = flags.rawValue
  }
  
  var contextLines: UInt32
  {
    get { context_lines }
    set { context_lines = newValue }
  }
}


final class GitDiff: Diff
{
  let diff: OpaquePointer  // git_diff
  
  static func unwrappingOptions(
      _ options: DiffOptions?,
      callback: (UnsafePointer<git_diff_options>?) -> Int32) -> Int32
  {
    if var options = options {
      return withUnsafePointer(to: &options) {
        callback($0)
      }
    }
    else {
      return callback(nil)
    }
  }
  
  /// Tree to tree
  init?(oldTree: (any Tree)?, newTree: (any Tree)?, repository: OpaquePointer,
        options: DiffOptions? = nil)
  {
    guard let diff = try? OpaquePointer.from({
      (diff) in
      GitDiff.unwrappingOptions(options) {
        git_diff_tree_to_tree(&diff, repository,
                              (oldTree as? GitTree)?.tree,
                              (newTree as? GitTree)?.tree, $0)
      }
    })
    else { return nil }

    _ = git_diff_find_similar(diff, nil)
    self.diff = diff
  }
  
  /// Index to working directory
  init?(repository: OpaquePointer, index: GitIndex,
        options: DiffOptions? = nil)
  {
    guard let diff = try? OpaquePointer.from({
      (diff) in
      GitDiff.unwrappingOptions(options) {
        git_diff_index_to_workdir(&diff, repository, index.index, $0)
      }
    })
    else { return nil }
    
    _ = git_diff_find_similar(diff, nil)
    self.diff = diff
  }
  
  /// Tree to working directory
  init?(repository: OpaquePointer, tree: GitTree,
        options: DiffOptions? = nil)
  {
    guard let diff = try? OpaquePointer.from({
      (diff) in
      GitDiff.unwrappingOptions(options) {
        git_diff_tree_to_workdir(&diff, repository, tree.tree, $0)
      }
    })
    else { return nil }
    
    _ = git_diff_find_similar(diff, nil)
    self.diff = diff
  }
  
  var deltaCount: Int { git_diff_num_deltas(diff) }
  
  func delta(at index: Int) -> git_diff_delta?
  {
    switch index {
      case 0..<deltaCount:
        return git_diff_get_delta(diff, index).pointee
      default:
        return nil
    }
  }
  
  func patch(at index: Int) -> GitPatch?
  {
    guard let patch = try? OpaquePointer.from({
      git_patch_from_diff(&$0, diff, index)
    })
    else { return nil }
    
    return GitPatch(gitPatch: patch)
  }

  func stats() -> GitDiffStats?
  {
    guard let stats = try? OpaquePointer.from({
      git_diff_get_stats(&$0, diff)
    })
    else { return nil }

    return GitDiffStats(stats: stats)
  }

  struct Deltas: Collection
  {
    let diff: GitDiff
    
    var startIndex: Int { 0 }
    var endIndex: Int { diff.deltaCount }
    
    subscript(position: Int) -> any DiffDelta { diff.delta(at: position)! }
    func index(after i: Int) -> Int { i + 1 }
  }
  
  struct Patches: Collection
  {
    let diff: GitDiff
    
    var startIndex: Int { 0 }
    var endIndex: Int { diff.deltaCount }
    
    subscript(position: Int) -> any Patch { diff.patch(at: position)! }
    func index(after i: Int) -> Int { i + 1 }
  }
  
  var deltas: Deltas { Deltas(diff: self) }
  var patches: Patches { Patches(diff: self) }
  
  deinit
  {
    git_diff_free(diff)
  }
}


extension Diff
{
  func delta(forNewPath path: String) -> (any DiffDelta)?
  {
    for index in 0..<deltaCount {
      if let delta = delta(at: index), delta.newFile.filePath == path {
        return delta
      }
    }
    return nil
  }
  
  func delta(forOldPath path: String) -> (any DiffDelta)?
  {
    for index in 0..<deltaCount {
      if let delta = delta(at: index), delta.oldFile.filePath == path {
        return delta
      }
    }
    return nil
  }
}


public struct GitDiffFile: DiffFile
{
  public typealias ObjectIdentifier = GitOID

  let diffFile: git_diff_file

  public var id: GitOID { .init(oid: diffFile.id) }
  public var size: UInt64 { diffFile.size }
  public var filePath: String
  {
    if let path = diffFile.path {
      return String(cString: path)
    }
    else {
      return ""
    }
  }
  public var diffFlags: DiffFlags { DiffFlags(rawValue: diffFile.flags) }
}

extension git_diff_line: DiffLine
{
  public var type: DiffLineType { DiffLineType(rawValue: UInt32(origin))
                                         ?? .context }
  public var oldLine: Int32 { old_lineno }
  public var newLine: Int32 { new_lineno }
  public var lineCount: Int32 { num_lines }
  public var byteCount: Int { content_len }
  public var offset: Int64 { content_offset }
  public var text: String
  {
    if let text = NSString(bytes: content, length: content_len,
                           encoding: String.Encoding.utf8.rawValue) as String? {
      return text.trimmingCharacters(in: .newlines)
    }
    else {
      return ""
    }
  }
}
