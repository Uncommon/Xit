import Foundation

// Has to inherit from NSObject so NSTreeNode can use it to sort
public class FileChange: NSObject
{
  @objc var path: String
  var change: DeltaStatus
  
  /// Repository-relative path to use for git operations
  var gitPath: String
  {
    return path.removingPrefix("\(WorkspaceTreeBuilder.rootName)/")
  }
  
  init(path: String, change: DeltaStatus = .unmodified)
  {
    self.path = path
    self.change = change
  }
  
  public override func isEqual(_ object: Any?) -> Bool
  {
    if let otherChange = object as? FileChange {
      return otherChange.path == path &&
             otherChange.change == change
    }
    return false
  }
}

extension FileChange // CustomStringConvertible
{
  public override var description: String
  {
    return "\(path) [\(change.description)]"
  }
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
  public func changes(for sha: String, parent parentOID: OID?) -> [FileChange]
  {
    guard sha != XTStagingSHA
    else {
      if let parentCommit = parentOID.flatMap({ commit(forOID: $0) }) {
        return Array(amendingChanges(parent: parentCommit))
      }
      else {
        return Array(stagingChanges)
      }
    }
    
    guard let commit = self.commit(forSHA: sha)
    else { return [] }
    
    let parentOID = parentOID ?? commit.parentOIDs.first
    guard let diff = self.diff(forSHA: commit.sha, parent: parentOID)
    else { return [] }
    var result = [FileChange]()
    
    for index in 0..<diff.deltaCount {
      guard let delta = diff.delta(at: index)
      else { continue }
      
      if delta.deltaStatus != .unmodified {
        let change = FileChange(path: delta.newFile.filePath,
                                change: delta.deltaStatus)
        
        result.append(change)
      }
    }
    return result
  }
  
  
  // Re-implementation of git_status_file with a given head commit
  func fileStatus(_ path: String, show: StatusShow = .indexAndWorkdir,
                  baseCommit: Commit?)
    -> (index: DeltaStatus, workspace: DeltaStatus)?
  {
    struct CallbackData
    {
      let path: String
      var status: git_status_t
    }
    
    var options = git_status_options.defaultOptions()
    let tree = baseCommit?.tree as? GitTree

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
    
    let result = withArrayOfCStrings([path]) {
      (paths: [UnsafeMutablePointer<CChar>?]) -> Int32 in
      let array = UnsafeMutablePointer<
                      UnsafeMutablePointer<Int8>?>(mutating: paths)
      
      options.pathspec.strings = array
      return git_status_foreach_ext(gtRepo.git_repository(), &options,
                                    callback, &data)
    }
    guard result == 0 || result == GIT_EUSER.rawValue
    else { return nil }
    
    return (index: DeltaStatus(indexStatus: data.status),
            workspace: DeltaStatus(worktreeStatus: data.status))
  }
  
  func statusChanges(_ show: StatusShow, showIgnored: Bool = false,
                     amend: Bool = false) -> [FileChange]
  {
    var options: StatusOptions = [.includeUntracked, .recurseUntrackedDirs]
    
    if showIgnored {
      options.formUnion([.includeIgnored, .recurseIgnoredDirs])
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
  
  public func unstagedChanges(showIgnored: Bool = false) -> [FileChange]
  {
    return mutex.withLock {
      if cachedIgnored == showIgnored,
         let result = cachedUnstagedChanges {
        return result
      }
      else {
        let result = statusChanges(.workdirOnly, showIgnored: showIgnored)
        
        cachedUnstagedChanges = result
        cachedIgnored = showIgnored
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
    guard let headCommit = headSHA.flatMap({ self.commit(forSHA: $0) }),
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
    let ignored = UnsafeMutablePointer<Int32>.allocate(capacity: 1)
    let result = git_ignore_path_is_ignored(ignored, gitRepo, path)
    
    return (result == 0) && (ignored.pointee != 0)
  }
}

extension XTRepository: FileStaging
{
  public var index: StagingIndex? { return GitIndex(repository: gitRepo) }

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
      var error: Error?
      
      git_checkout_init_options(&options, UInt32(GIT_CHECKOUT_OPTIONS_VERSION))
      [file].withGitStringArray {
        (stringarray) in
        options.checkout_strategy = GIT_CHECKOUT_FORCE.rawValue +
          GIT_CHECKOUT_RECREATE_MISSING.rawValue
        options.paths = stringarray
        
        let result = git_checkout_tree(self.gitRepo, nil, &options)
        
        if result < 0 {
          error = Error.gitError(result)
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
      else { throw Error.unexpected }
    
    if let headOID = headReference?.resolve()?.targetOID {
      guard let headCommit = commit(forOID: headOID),
        let headTree = headCommit.tree
        else { throw Error.unexpected }
      
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
    else { throw Error.unexpected }
    
    switch status {
      case .modified, .added:
        try index.add(path: file)
      case .deleted:
        try index.remove(path: file)
      default:
        throw Error.unexpected
    }
    
    invalidateIndex()
  }
  
  /// Unstages the file relative to HEAD's parent
  public func amendUnstage(file: String) throws
  {
    let status = try self.amendingStagedStatus(for: file)
    let index = try gtRepo.index()
    
    switch status {
      
      case .added:
        try index.removeFile(file)
      
      case .modified, .deleted:
        guard let headCommit = headSHA.flatMap({ self.commit(forSHA: $0) }),
              let parentOID = headCommit.parentOIDs.first
        else {
          throw Error.commitNotFound(headSHA)
        }
        guard let parentCommit = commit(forOID: parentOID)
        else {
          throw Error.commitNotFound(parentOID.sha)
        }
        guard let entry = parentCommit.tree?.entry(path: file),
              let blob = entry.object as? Blob
        else {
          throw Error.fileNotFound(file)
        }
        
        try blob.withData {
          try index.add($0, withPath: file)
        }
      
      default:
        break
    }
    
    try index.write()
    invalidateIndex()
  }
  
  /// Creates a new commit with the given message.
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
    
    outputBlock?(outputString)
    invalidateIndex()
  }
}
