import Foundation

extension XitChange
{
  init(delta: GTDeltaType)
  {
    self = XitChange(rawValue: UInt(delta.rawValue)) ?? .unmodified
  }
  
  init(gitDelta: git_delta_t)
  {
    self = XitChange(rawValue: UInt(gitDelta.rawValue)) ?? .unmodified
  }
  
  init(indexStatus: git_status_t)
  {
    switch indexStatus {
      case let s where s.test(GIT_STATUS_INDEX_NEW):
        self = .added
      case let s where s.test(GIT_STATUS_INDEX_MODIFIED):
        self = .modified
      case let s where s.test(GIT_STATUS_INDEX_DELETED):
        self = .deleted
      case let s where s.test(GIT_STATUS_INDEX_RENAMED):
        self = .renamed
      default:
        self = .unmodified
    }
  }
  
  init(worktreeStatus: git_status_t)
  {
    switch worktreeStatus {
      case let s where s.test(GIT_STATUS_WT_NEW):
        self = .added
      case let s where s.test(GIT_STATUS_WT_MODIFIED):
        self = .modified
      case let s where s.test(GIT_STATUS_WT_DELETED):
        self = .deleted
      case let s where s.test(GIT_STATUS_WT_RENAMED):
        self = .renamed
      case let s where s.test(GIT_STATUS_IGNORED):
        self = .ignored
      case let s where s.test(GIT_STATUS_CONFLICTED):
        self = .conflict
      default:
        self = .unmodified
    }
  }
}

struct WorkspaceFileStatus
{
  let change, unstagedChange: XitChange
}

// Has to inherit from NSObject so NSTreeNode can use it to sort
class FileChange: NSObject
{
  var path: String
  var change, unstagedChange: XitChange
  
  init(path: String, change: XitChange = .unmodified,
       unstagedChange: XitChange = .unmodified)
  {
    self.path = path
    self.change = change
    self.unstagedChange = unstagedChange
  }
}

class FileStaging: FileChange
{
  let destinationPath: String
  
  init(path: String, destinationPath: String,
       change: XitChange = .unmodified,
       unstagedChange: XitChange = .unmodified)
  {
    self.destinationPath = destinationPath
    super.init(path: path, change: change, unstagedChange: unstagedChange)
  }
}

extension XTRepository
{
  /// A path:status dictionary for locally changed files.
  var workspaceStatus: [String: WorkspaceFileStatus]
  {
    var result = [String: WorkspaceFileStatus]()
    let options = [GTRepositoryStatusOptionsFlagsKey:
                   GIT_STATUS_OPT_INCLUDE_UNTRACKED.rawValue]
    
    try? gtRepo.enumerateFileStatus(options: options) {
      (headToIndex, indexToWorking, _) in
      guard let path = headToIndex?.oldFile?.path ??
                       indexToWorking?.oldFile?.path
      else { return }
      
      let status = WorkspaceFileStatus(
            change: headToIndex.map { XitChange(delta: $0.status) }
                    ?? .unmodified,
            unstagedChange: indexToWorking.map { XitChange(delta: $0.status) }
                            ?? .unmodified)
      result[path] = status
    }
    return result
  }
 
  static let textNames = ["AUTHORS", "CONTRIBUTING", "COPYING", "LICENSE",
                          "Makefile", "README"]
  
  /// Returns true if the file seems to be text, based on its name.
  static func isTextFile(_ path: String) -> Bool
  {
    let name = (path as NSString).lastPathComponent
    guard !name.isEmpty
    else { return false }
    
    if XTRepository.textNames.contains(name) {
      return true
    }
    
    let ext = (name as NSString).pathExtension
    guard !ext.isEmpty
    else { return false }
    
    let unmanaged = UTTypeCreatePreferredIdentifierForTag(
          kUTTagClassFilenameExtension, ext as CFString, nil)
    let utType = unmanaged?.takeRetainedValue()
    
    return utType.map { UTTypeConformsTo($0, kUTTypeText) } ?? false
  }
  
  /// Returns a file delta from a given diff.
  func delta(from diff: GTDiff, path: String) -> XTDiffDelta?
  {
    var result: XTDiffDelta?
    
    diff.enumerateDeltas {
      (delta, stop) in
      if delta.newFile.path == path {
        stop.pointee = true
        result = delta
      }
    }
    return result
  }
  
  func status(for path: String) throws -> WorkspaceFileStatus
  {
    let flagsInt = UnsafeMutablePointer<UInt32>.allocate(capacity: 1)
    let result = git_status_file(flagsInt, gtRepo.git_repository(), path)
    
    try Error.throwIfError(result)
    
    let flags = git_status_t(rawValue: flagsInt.pointee)
    
    return WorkspaceFileStatus(
        change: XitChange(indexStatus: flags),
        unstagedChange: XitChange(worktreeStatus: flags))
  }
  
  func amendingStatus(for path: String) throws -> WorkspaceFileStatus
  {
    guard let headCommit = headSHA.flatMap({ self.commit(forSHA: $0) }),
          let previousCommit = headCommit.parentOIDs.first
                                         .flatMap({ self.commit(forOID: $0) }),
          let tree = previousCommit.tree?.git_tree()
    else {
      return WorkspaceFileStatus(change: .unmodified,
                                 unstagedChange: .unmodified)
    }
    let flagsInt = UnsafeMutablePointer<UInt32>.allocate(capacity: 1)
    let result = git_status_file_at(flagsInt, gtRepo.git_repository(), path,
                                    tree)
    
    try Error.throwIfError(result)
    
    let flags = git_status_t(rawValue: flagsInt.pointee)
    
    return WorkspaceFileStatus(
        change: XitChange(indexStatus: flags),
        unstagedChange: XitChange(worktreeStatus: flags))
  }
  
  /// Stages the given file to the index.
  @objc(stageFile:error:)
  func stage(file: String) throws
  {
    let fullPath = file.hasPrefix("/") ? file :
          repoURL.path.appending(pathComponent:file)
    let exists = FileManager.default.fileExists(atPath: fullPath)
    let args = [exists ? "add" : "rm", file]
    
    _ = try executeGit(args: args, writes: true)
  }
  
  /// Stages all modified files.
  func stageAllFiles() throws
  {
    _ = try executeGit(args: ["add", "--all"], writes: true)
  }
  
  /// Unstages the given file.
  func unstage(file: String) throws
  {
    let args = hasHeadReference() ? ["reset", "-q", "HEAD", file]
                                  : ["rm", "--cached", file]
    
    _ = try executeGit(args: args, writes: true)
  }
  
  /// Stages the file relative to HEAD's parent
  func amendStage(file: String) throws
  {
    let status = try self.amendingStatus(for: file)
    let index = try gtRepo.index()
    
    switch status.unstagedChange {
      
      case .modified, .added:
        try index.addFile(file)
        break
        
      case .deleted:
        try index.removeFile(file)
        break
        
      default:
        throw Error.unexpected
    }
  }
  
  /// Unstages the file relative to HEAD's parent
  func amendUnstage(file: String) throws
  {
    let status = try self.amendingStatus(for: file)
    let index = try gtRepo.index()
    
    switch status.change {
      
      case .added:
        try index.removeFile(file)
      
      case .modified, .deleted:
        guard let headCommit = headSHA.flatMap({ commit(forSHA: $0) }),
              let parentCommit = headCommit.parentOIDs.first
                                 .flatMap({ commit(forOID: $0) }),
              let entry = try parentCommit.tree?.entry(withPath: file),
              let oid = entry.oid.flatMap({ GitOID(oid: $0.git_oid().pointee) }),
              let blob = GitBlob(repository: self, oid: oid)
        else {
          // None of the above should fail with a modified/deleted status.
          throw Error.unexpected
        }
        
        try blob.withData {
          try index.add($0, withPath: file)
        }
      
      default:
        break
    }
    
    try index.write()
  }
  
  // Creates a new commit with the given message.
  @objc(commitWithMessage:amend:outputBlock:error:)
  func commit(message: String, amend: Bool,
              outputBlock: ((String) -> Void)?) throws
  {
    var args = ["commit", "-F", "-"]
    
    if amend {
      args.append("--amend")
    }
    
    let output = try executeGit(args: args,
                                stdIn: message, writes: true)
    let outputString = String(data: output, encoding: .utf8) ?? ""
    
    outputBlock.map { $0(outputString) }
  }
}
