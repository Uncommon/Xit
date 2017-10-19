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
  
  // Returns the changes for the given commit.
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
  
  func amendingStatus(for path: String) throws -> WorkspaceFileStatus
  {
    guard let headCommit = headSHA.flatMap({ self.commit(forSHA: $0) }),
          let previousCommit = headCommit.parentOIDs.first
                                         .flatMap({ self.commit(forOID: $0) }),
          let tree = previousCommit.tree as? GitTree
    else {
      return WorkspaceFileStatus(change: .unmodified,
                                 unstagedChange: .unmodified)
    }
    let flagsInt = UnsafeMutablePointer<UInt32>.allocate(capacity: 1)
    let result = git_status_file_at(flagsInt, gtRepo.git_repository(), path,
                                    tree.tree)
    
    try Error.throwIfError(result)
    
    let flags = git_status_t(rawValue: flagsInt.pointee)
    
    return WorkspaceFileStatus(
        change: DeltaStatus(indexStatus: flags),
        unstagedChange: DeltaStatus(worktreeStatus: flags))
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
              let entry = parentCommit.tree?.entry(path: file),
              let blob = GitBlob(repository: self, oid: entry.oid)
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
