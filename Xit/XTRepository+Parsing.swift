import Foundation

public struct WorkspaceFileStatus
{
  let change, unstagedChange: DeltaStatus
}

// Has to inherit from NSObject so NSTreeNode can use it to sort
public class FileChange: NSObject
{
  @objc var path: String
  var change: DeltaStatus
  
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
  // A path:status dictionary for locally changed files.
  public var workspaceStatus: [String: WorkspaceFileStatus]
  {
    var result = [String: WorkspaceFileStatus]()
    guard let statusList = GitStatusList(repository: gitRepo,
                                         options: [.includeUntracked])
    else { return [:] }
    
    for entry in statusList {
      guard let path = entry.headToIndex?.oldFile.filePath ??
                       entry.indexToWorkdir?.oldFile.filePath
      else { continue }
      let status = WorkspaceFileStatus(
            change: entry.headToIndex?.deltaStatus ?? .unmodified,
            unstagedChange: entry.indexToWorkdir?.deltaStatus ?? .unmodified)
      
      result[path] = status
    }
    return result
  }
  
  // Returns the changes for the given commit.
  public func changes(for sha: String, parent parentOID: OID?) -> [FileChange]
  {
    guard sha != XTStagingSHA
    else { return stagingChanges() }
    
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

  // TODO: use statusChanges instead
  func stagingChanges() -> [FileChange]
  {
    var result = [FileStagingChange]()
    guard let statusList = GitStatusList(repository: gitRepo,
                                         options: [.includeUntracked,
                                                   .recurseUntrackedDirs])
    else { return [] }
    
    for entry in statusList {
      guard let delta = entry.headToIndex ?? entry.indexToWorkdir
      else { continue }
      let stagedChange = entry.headToIndex?.deltaStatus ?? .unmodified
      let change = FileStagingChange(path: delta.oldFile.filePath,
                                     destinationPath: delta.newFile.filePath,
                                     change: stagedChange)
      
      result.append(change)
    }
    return result
  }
  
  func statusChanges(_ show: StatusShow) -> [FileChange]
  {
    guard let statusList = GitStatusList(repository: gitRepo, show: show,
                                         options: [.includeUntracked,
                                                   .recurseUntrackedDirs])
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
  
  public func unstagedChanges() -> [FileChange]
  {
    if let result = cachedUnstagedChanges {
      return result
    }
    else {
      let result = statusChanges(.workdirOnly)
      
      cachedUnstagedChanges = result
      return result
    }
  }
}

extension XTRepository: FileStaging
{
  // Stages the given file to the index.
  @objc(stageFile:error:)
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
  @objc(revertFile:error:)
  public func revert(file: String) throws
  {
    let status = try self.status(file: file)
    
    if status.0 == .untracked {
      try FileManager.default.removeItem(at: repoURL.appendingPathComponent(file))
    }
    else {
      var options = git_checkout_options.defaultOptions()
      var error: Error? = nil
      
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
  }

  // Stages all modified files.
  public func stageAllFiles() throws
  {
    _ = try executeGit(args: ["add", "--all"], writes: true)
  }
  
  public func unstageAllFiles() throws
  {
    guard let index = GitIndex(repository: self)
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
  }

  // Unstages all stages files.
  public func unstage(file: String) throws
  {
    let args = hasHeadReference() ? ["reset", "-q", "HEAD", file]
                                  : ["rm", "--cached", file]
    
    _ = try executeGit(args: args, writes: true)
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
    
    outputBlock?(outputString)
  }
}
