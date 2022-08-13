import Foundation

// Has to inherit from NSObject so NSTreeNode can use it to sort
public class FileChange: NSObject
{
  @objc var path: String
  let oldPath: String
  var status: DeltaStatus
  
  /// Repository-relative path to use for git operations
  var gitPath: String
  { path.droppingPrefix("\(WorkspaceTreeBuilder.rootName)/") }
  
  init(path: String, oldPath: String = "", change: DeltaStatus = .unmodified)
  {
    self.path = path
    self.oldPath = oldPath
    self.status = change
  }
  
  public override func isEqual(_ object: Any?) -> Bool
  {
    if let otherChange = object as? FileChange {
      return otherChange.path == path &&
             otherChange.status == status
    }
    return false
  }
}

extension FileChange // CustomStringConvertible
{
  public override var description: String
  { "\(path) [\(status.description)]" }
}

class FileStagingChange: FileChange
{
  let destinationPath: String
  
  init(path: String, destinationPath: String,
       change: DeltaStatus = .unmodified)
  {
    self.destinationPath = destinationPath
    super.init(path: path, change: change)
  }
}

extension XTRepository: FileStatusDetection
{
  /// Returns the changes for the given commit.
  public func changes(for oid: any OID,
                      parent parentOID: (any OID)?) -> [FileChange]
  {
    guard oid != SpecialOID.staging
    else {
      let parentOID = parentOID as? GitOID
      if let parentCommit = parentOID.flatMap({ commit(forOID: $0) }) {
        return Array(amendingChanges(parent: parentCommit))
      }
      else {
        return Array(stagingChanges)
      }
    }
    
    guard let oid = oid as? GitOID,
          let commit = self.commit(forOID: oid)
    else { return [] }
    
    let parentOID = parentOID ?? commit.parentOIDs.first
    guard let diff = self.diff(forOID: commit.id, parent: parentOID)
    else { return [] }
    let result = diff.deltas
      .filter { $0.deltaStatus != .unmodified }
      .map { FileChange(path: $0.newFile.filePath,
                        oldPath: $0.oldFile.filePath,
                        change: $0.deltaStatus) }

    return result
  }
  
  /// Returns the unstaged and staged status of the given file.
  public func status(file: String) throws -> (DeltaStatus, DeltaStatus)
  {
    var statusFlags: UInt32 = 0
    let result = git_status_file(&statusFlags, gitRepo, file)

    try RepoError.throwIfGitError(result)

    let flags = git_status_t(statusFlags)
    var unstagedChange = DeltaStatus.unmodified
    var stagedChange = DeltaStatus.unmodified

    switch flags {
      case _ where flags.contains(GIT_STATUS_WT_NEW):
        unstagedChange = .untracked
      case _ where flags.contains(GIT_STATUS_WT_MODIFIED),
           _ where flags.contains(GIT_STATUS_WT_TYPECHANGE):
        unstagedChange = .modified
      case _ where flags.contains(GIT_STATUS_WT_DELETED):
        unstagedChange = .deleted
      case _ where flags.contains(GIT_STATUS_WT_RENAMED):
        unstagedChange = .renamed
      case _ where flags.contains(GIT_STATUS_IGNORED):
        unstagedChange = .ignored
      case _ where flags.contains(GIT_STATUS_CONFLICTED):
        unstagedChange = .conflict
      // ignoring GIT_STATUS_WT_UNREADABLE
      default:
        break
    }

    switch flags {
      case _ where flags.contains(GIT_STATUS_INDEX_NEW):
        stagedChange = .added
      case _ where flags.contains(GIT_STATUS_INDEX_MODIFIED),
           _ where flags.contains(GIT_STATUS_WT_TYPECHANGE):
        stagedChange = .modified
      case _ where flags.contains(GIT_STATUS_INDEX_DELETED):
        stagedChange = .deleted
      case _ where flags.contains(GIT_STATUS_INDEX_RENAMED):
        stagedChange = .renamed
      default:
        break
    }

    return (unstagedChange, stagedChange)
  }

  // Re-implementation of git_status_file with a given head commit
  func fileStatus(_ path: String,
                  show: StatusShow = .indexAndWorkdir,
                  baseCommit: (any Xit.Commit)?)
    -> (index: DeltaStatus, workspace: DeltaStatus)?
  {
    struct CallbackData: Sendable
    {
      let path: String
      var status: git_status_t
    }
    
    var options = git_status_options.defaultOptions()
    let tree = (baseCommit as? GitCommit)?.tree

    options.show = git_status_show_t(UInt32(show.rawValue))
    options.flags = GIT_STATUS_OPT_INCLUDE_IGNORED.rawValue |
                    GIT_STATUS_OPT_RECURSE_IGNORED_DIRS.rawValue |
                    GIT_STATUS_OPT_INCLUDE_UNTRACKED.rawValue |
                    GIT_STATUS_OPT_RECURSE_UNTRACKED_DIRS.rawValue |
                    GIT_STATUS_OPT_INCLUDE_UNMODIFIED.rawValue |
                    GIT_STATUS_OPT_DISABLE_PATHSPEC_MATCH.rawValue
    options.baseline = tree?.tree
    options.pathspec.count = 1
    
    var data = CallbackData(path: path, status: git_status_t(rawValue: 0))
    let callback: git_status_cb = {
      (path, status, data) in
      guard let callbackData = data?.assumingMemoryBound(to: CallbackData.self),
            let pathString = path.flatMap({ String(cString: $0) })
      else { return 0 }
      
      if pathString == callbackData.pointee.path {
        callbackData.pointee.status = git_status_t(rawValue: status)
        return GIT_EUSER.rawValue
      }
      return 0
    }
    
    let result = withMutableArrayOfCStrings([path]) {
      (paths: inout [UnsafeMutablePointer<CChar>?]) -> Int32 in
      paths.withUnsafeMutableBufferPointer {
        options.pathspec.strings = $0.baseAddress
        return git_status_foreach_ext(gitRepo, &options, callback, &data)
      }
    }
    guard result == 0 || result == GIT_EUSER.rawValue
    else { return nil }
    
    return (index: DeltaStatus(indexStatus: data.status),
            workspace: DeltaStatus(worktreeStatus: data.status))
  }
  
  func statusChanges(_ show: StatusShow,
                     showIgnored: Bool = false,
                     recurse: Bool = true,
                     amend: Bool = false) -> [FileChange]
  {
    var options: StatusOptions = [
      .includeUntracked,
      .renamesHeadToIndex,
      .renamesIndexToWorkdir,
    ]
    
    if showIgnored {
      options.formUnion([.includeIgnored])
      if recurse {
        options.formUnion([.recurseIgnoredDirs])
      }
    }
    if recurse {
      options.formUnion([.recurseUntrackedDirs])
    }
    if amend {
      options.formUnion(.amending)
    }
    
    guard let statusList = GitStatusList(repository: self, show: show,
                                         options: options)
    else { return [] }
    
    return statusList.compactMap {
      (entry) in
      let delta = (show == .indexOnly) ? entry.headToIndex : entry.indexToWorkdir
      
      return delta.map { FileChange(path: $0.newFile.filePath,
                                    oldPath: $0.oldFile.filePath,
                                    change: $0.deltaStatus) }
    }
  }
  
  public func stagedChanges() -> [FileChange]
  {
    if let result = cachedStagedChanges {
      return result
    }
    else {
      let result = statusChanges(.indexOnly)
      
      cachedStagedChanges = result
      return result
    }
  }
  
  public func amendingStagedChanges() -> [FileChange]
  {
    if let result = cachedAmendChanges {
      return result
    }
    else {
      let result = statusChanges(.indexOnly, amend: true)
      
      cachedAmendChanges = result
      return result
    }
  }
  
  public func unstagedChanges(showIgnored: Bool = false,
                              recurseUntracked: Bool = true,
                              useCache: Bool = true) -> [FileChange]
  {
    return mutex.withLock {
      if useCache && (cachedIgnored == showIgnored),
         let result = cachedUnstagedChanges {
        return result
      }
      else {
        let result = statusChanges(.workdirOnly,
                                   showIgnored: showIgnored,
                                   recurse: recurseUntracked)

        if useCache {
          cachedUnstagedChanges = result
          cachedIgnored = showIgnored
        }
        return result
      }
    }
  }
  
  public func stagedStatus(for path: String) throws -> DeltaStatus
  {
    return fileStatus(path, show: .indexOnly, baseCommit: nil)?.index ??
           .unmodified
  }
  
  public func unstagedStatus(for path: String) throws -> DeltaStatus
  {
    return fileStatus(path, show: .workdirOnly, baseCommit: nil)?.workspace ??
           .unmodified
  }
  
  func amendingStatus(for path: String, show: StatusShow) throws
    -> (index: DeltaStatus, workspace: DeltaStatus)
  {
    guard let headCommit = self.headCommit,
          let previousCommit = headCommit.parentOIDs.first
                                .flatMap({ self.commit(forOID: $0) }),
          let status = fileStatus(path, show: show, baseCommit: previousCommit)
    else {
      return (index: .unmodified, workspace: .unmodified)
    }
    
    return status
  }
  
  public func amendingStagedStatus(for path: String) throws -> DeltaStatus
  {
    return try amendingStatus(for: path, show: .indexOnly).index
  }
  
  public func amendingUnstagedStatus(for path: String) throws -> DeltaStatus
  {
    return try amendingStatus(for: path, show: .workdirOnly).workspace
  }
  
  /// Returns true if the path is ignored according to the repository's
  /// ignore rules.
  public func isIgnored(path: String) -> Bool
  {
    var ignored: Int32 = 0
    let result = git_ignore_path_is_ignored(&ignored, gitRepo, path)
    
    return (result == 0) && (ignored != 0)
  }
}

extension XTRepository: FileStaging
{
  public var index: (any StagingIndex)? { GitIndex(repository: gitRepo) }

  /// Stages the given file to the index.
  public func stage(file: String) throws
  {
    let fullPath = file.hasPrefix("/") ? file :
          repoURL.path.appending(pathComponent: file)
    let exists = FileManager.default.fileExists(atPath: fullPath)
    let args = [exists ? "add" : "rm", file]
    
    _ = try executeGit(args: args, writes: true)
    invalidateIndex()
  }

  /// Reverts the given workspace file to the contents at HEAD.
  public func revert(file: String) throws
  {
    let status = try self.status(file: file)
    
    if status.0 == .untracked {
      try FileManager.default.removeItem(at: repoURL.appendingPathComponent(file))
    }
    else {
      var options = git_checkout_options.defaultOptions()
      var error: RepoError?
      
      git_checkout_init_options(&options, UInt32(GIT_CHECKOUT_OPTIONS_VERSION))
      [file].withGitStringArray {
        (stringarray) in
        options.checkout_strategy = GIT_CHECKOUT_FORCE.rawValue +
          GIT_CHECKOUT_RECREATE_MISSING.rawValue
        options.paths = stringarray
        
        let result = git_checkout_tree(self.gitRepo, nil, &options)
        
        if result < 0 {
          error = RepoError.gitError(result)
        }
      }
      
      try error.map { throw $0 }
    }
    invalidateIndex()
  }

  /// Stages all modified files.
  public func stageAllFiles() throws
  {
    _ = try executeGit(args: ["add", "--all"], writes: true)
    invalidateIndex()
  }
  
  public func unstageAllFiles() throws
  {
    guard let index = GitIndex(repository: gitRepo)
    else { throw RepoError.unexpected }
    
    if let headOID = headReference?.resolve()?.targetOID {
      guard let headCommit = commit(forOID: headOID),
            let headTree = headCommit.tree
      else { throw RepoError.unexpected }
      
      try index.read(tree: headTree)
    }
    else {
      // If there is no head, then this is the first commit
      try index.clear()
    }
    
    try index.save()
    invalidateIndex()
  }

  /// Unstages the given file.
  public func unstage(file: String) throws
  {
    let args = hasHeadReference() ? ["reset", "-q", "HEAD", file]
                                  : ["rm", "--cached", file]
    
    _ = try executeGit(args: args, writes: true)
    invalidateIndex()
  }
  
  /// Stages the file relative to HEAD's parent
  public func amendStage(file: String) throws
  {
    let status = try self.amendingUnstagedStatus(for: file)
    guard let index = GitIndex(repository: gitRepo)
    else { throw RepoError.unexpected }
    
    switch status {
      case .modified, .added:
        try index.add(path: file)
      case .deleted:
        try index.remove(path: file)
      default:
        throw RepoError.unexpected
    }
    
    invalidateIndex()
  }
  
  /// Unstages the file relative to HEAD's parent
  public func amendUnstage(file: String) throws
  {
    let status = try self.amendingStagedStatus(for: file)
    guard let index = self.index
    else {
      throw RepoError.unexpected
    }
    
    switch status {
      
      case .added:
        try index.remove(path: file)
      
      case .modified, .deleted:
        guard let headCommit = self.headCommit,
              let parentOID = headCommit.parentOIDs.first
        else {
          throw RepoError.commitNotFound(sha: headSHA)
        }
        guard let parentCommit = commit(forOID: parentOID)
        else {
          throw RepoError.commitNotFound(sha: parentOID.sha)
        }
        guard let entry = parentCommit.anyTree?.anyEntry(path: file),
              let blob = entry.object as? Blob
        else {
          throw RepoError.fileNotFound(path: file)
        }
        
        try blob.withUnsafeBytes {
          try index.add(data: $0, count: Int(blob.dataSize), path: file)
        }
      
      default:
        break
    }
    
    try index.save()
    invalidateIndex()
  }
}
