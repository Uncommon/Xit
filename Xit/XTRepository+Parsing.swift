import Foundation

public struct WorkspaceFileStatus
{
  let change, unstagedChange: DeltaStatus
}

// Has to inherit from NSObject so NSTreeNode can use it to sort
public class FileChange: NSObject
{
  @objc var path: String
  var change, unstagedChange: DeltaStatus
  
  init(path: String, change: DeltaStatus = .unmodified,
       unstagedChange: DeltaStatus = .unmodified)
  {
    self.path = path
    self.change = change
    self.unstagedChange = unstagedChange
  }
}

class FileStagingChange: FileChange
{
  let destinationPath: String
  
  init(path: String, destinationPath: String,
       change: DeltaStatus = .unmodified,
       unstagedChange: DeltaStatus = .unmodified)
  {
    self.destinationPath = destinationPath
    super.init(path: path, change: change, unstagedChange: unstagedChange)
  }
}

extension XTRepository: FileStaging
{
  /// A path:status dictionary for locally changed files.
  public var workspaceStatus: [String: WorkspaceFileStatus]
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
            change: headToIndex.map { DeltaStatus(delta: $0.status) }
                    ?? .unmodified,
            unstagedChange: indexToWorking.map { DeltaStatus(delta: $0.status) }
                            ?? .unmodified)
      result[path] = status
    }
    return result
  }
  
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
    
    guard let commit = self.commit(forSHA: sha),
          let sha = commit.sha
    else { return [] }
    
    let parentOID = parentOID ?? commit.parentOIDs.first
    guard let diff = self.diff(forSHA: sha, parent: parentOID)
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
  
  func status(for path: String) throws -> WorkspaceFileStatus
  {
    let flagsInt = UnsafeMutablePointer<UInt32>.allocate(capacity: 1)
    let result = git_status_file(flagsInt, gtRepo.git_repository(), path)
    
    try Error.throwIfError(result)
    
    let flags = git_status_t(rawValue: flagsInt.pointee)
    
    return WorkspaceFileStatus(
        change: DeltaStatus(indexStatus: flags),
        unstagedChange: DeltaStatus(worktreeStatus: flags))
  }
  
  // Re-implementation of git_status_file with a given head commit
  func fileStatus(_ path: String, baseCommit: Commit?) -> WorkspaceFileStatus?
  {
    struct CallbackData
    {
      let path: String
      var status: git_status_t
    }
    
    var options = git_status_options.defaultOptions()
    let tree = baseCommit?.tree as? GitTree

    options.show = GIT_STATUS_SHOW_INDEX_AND_WORKDIR
    options.flags = GIT_STATUS_OPT_INCLUDE_IGNORED.rawValue |
                    GIT_STATUS_OPT_RECURSE_IGNORED_DIRS.rawValue |
                    GIT_STATUS_OPT_INCLUDE_UNTRACKED.rawValue |
                    GIT_STATUS_OPT_RECURSE_UNTRACKED_DIRS.rawValue |
                    GIT_STATUS_OPT_INCLUDE_UNMODIFIED.rawValue |
                    GIT_STATUS_OPT_DISABLE_PATHSPEC_MATCH.rawValue
    options.head_tree = tree?.tree
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
    
    return WorkspaceFileStatus(
        change: DeltaStatus(indexStatus: data.status),
        unstagedChange: DeltaStatus(worktreeStatus: data.status))
  }
  
  func amendingStatus(for path: String) throws -> WorkspaceFileStatus
  {
    guard let headCommit = headSHA.flatMap({ self.commit(forSHA: $0) }),
          let previousCommit = headCommit.parentOIDs.first
                                         .flatMap({ self.commit(forOID: $0) }),
          let status = fileStatus(path, baseCommit: previousCommit)
    else {
      return WorkspaceFileStatus(change: .unmodified,
                                 unstagedChange: .unmodified)
    }
    
    return status
  }

  /// Stages the given file to the index.
  @objc(stageFile:error:)
  func stage(file: String) throws
  {
    let fullPath = file.hasPrefix("/") ? file :
          repoURL.path.appending(pathComponent: file)
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
      
      case .deleted:
        try index.removeFile(file)
        
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
