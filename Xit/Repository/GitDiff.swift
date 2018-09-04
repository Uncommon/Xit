import Foundation

public protocol Diff: AnyObject
{
  var deltaCount: Int { get }
  
  func delta(at index: Int) -> DiffDelta?
  func patch(at index: Int) -> Patch?
}

public protocol DiffFile
{
  var oid: OID { get }
  var filePath: String { get }
  var size: Int64 { get }
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
    get { return context_lines }
    set { context_lines = newValue }
  }
}


class GitDiff: Diff
{
  let diff: OpaquePointer  // git_diff
  
  static func unwrappingOptions(
      _ options: DiffOptions?,
      callback: (UnsafePointer<git_diff_options>?) -> Int32) -> Int32
  {
    if var options = options {
      return withUnsafePointer(to: &options) {
        return callback($0)
      }
    }
    else {
      return callback(nil)
    }
  }
  
  /// Tree to tree
  init?(oldTree: Tree?, newTree: Tree?, repository: OpaquePointer,
        options: DiffOptions? = nil)
  {
    var diff: OpaquePointer?
    let result: Int32 = GitDiff.unwrappingOptions(options) {
      return git_diff_tree_to_tree(&diff, repository,
                                     (oldTree as? GitTree)?.tree,
                                     (newTree as? GitTree)?.tree, $0)
    }
    guard result == 0,
          let finalDiff = diff
    else { return nil }
    
    self.diff = finalDiff
  }
  
  /// Index to working directory
  init?(repository: OpaquePointer, index: GitIndex,
        options: DiffOptions? = nil)
  {
    var diff: OpaquePointer?
    let result = GitDiff.unwrappingOptions(options) {
      return git_diff_index_to_workdir(&diff, repository, index.index, $0)
    }
    guard result == 0,
          let finalDiff = diff
    else { return nil }
    
    self.diff = finalDiff
  }
  
  /// Tree to working directory
  init?(repository: OpaquePointer, tree: GitTree,
        options: DiffOptions? = nil)
  {
    var diff: OpaquePointer?
    let result = GitDiff.unwrappingOptions(options) {
      return git_diff_tree_to_workdir(&diff, repository, tree.tree, $0)
    }
    guard result == 0,
          let finalDiff = diff
    else { return nil }
    
    self.diff = finalDiff
  }
  
  var deltaCount: Int { return git_diff_num_deltas(diff) }
  
  func delta(at index: Int) -> DiffDelta?
  {
    switch index {
      case 0..<deltaCount:
        return git_diff_get_delta(diff, index).pointee
      default:
        return nil
    }
  }
  
  func patch(at index: Int) -> Patch?
  {
    var patch: OpaquePointer?
    let result = git_patch_from_diff(&patch, diff, index)
    guard result == 0,
          let finalPatch = patch
    else { return nil }
    
    return GitPatch(gitPatch: finalPatch)
  }
  
  struct Deltas: Collection
  {
    let diff: GitDiff
    
    var startIndex: Int { return 0 }
    var endIndex: Int { return diff.deltaCount }
    
    subscript(position: Int) -> DiffDelta { return diff.delta(at: position)! }
    func index(after i: Int) -> Int { return i + 1 }
  }
  
  struct Patches: Collection
  {
    let diff: GitDiff
    
    var startIndex: Int { return 0 }
    var endIndex: Int { return diff.deltaCount }
    
    subscript(position: Int) -> Patch { return diff.patch(at: position)! }
    func index(after i: Int) -> Int { return i + 1 }
  }
  
  var deltas: Deltas { return Deltas(diff: self) }
  var patches: Patches { return Patches(diff: self) }
  
  deinit
  {
    git_diff_free(diff)
  }
}


extension Diff
{
  func delta(forNewPath path: String) -> DiffDelta?
  {
    for index in 0..<deltaCount {
      if let delta = delta(at: index), delta.newFile.filePath == path {
        return delta
      }
    }
    return nil
  }
  
  func delta(forOldPath path: String) -> DiffDelta?
  {
    for index in 0..<deltaCount {
      if let delta = delta(at: index), delta.oldFile.filePath == path {
        return delta
      }
    }
    return nil
  }
}


extension git_diff_file: DiffFile
{
  public var oid: OID { return GitOID(oid: id) }
  public var filePath: String
  {
    if let path = self.path {
      return String(cString: path)
    }
    else {
      return ""
    }
  }
  public var diffFlags: DiffFlags { return DiffFlags(rawValue: flags) }
}

extension git_diff_line: DiffLine
{
  public var type: DiffLineType { return DiffLineType(rawValue: UInt32(origin))
                                         ?? .context }
  public var oldLine: Int32 { return old_lineno }
  public var newLine: Int32 { return new_lineno }
  public var lineCount: Int32 { return num_lines }
  public var byteCount: Int { return content_len }
  public var offset: Int64 { return content_offset }
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
