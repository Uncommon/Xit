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
  // A path:status dictionary for locally changed files.
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
      else { return stagingChanges() }
    
    guard let commit = self.commit(forSHA: sha),
      let sha = commit.sha
      else { return [] }
    
    let parentOID = parentOID ?? commit.parentOIDs.first
    let diff = self.diff(forSHA: sha, parent: parentOID)
    var result = [FileChange]()
    
    diff?.enumerateDeltas {
      (delta, _) in
      if delta.type != .unmodified {
        let change = FileChange(path: delta.newFile.path,
                                change: DeltaStatus(delta: delta.type))
        
        result.append(change)
      }
    }
    return result
  }

  func stagingChanges() -> [FileChange]
  {
    var result = [FileStagingChange]()
    let flags = GTRepositoryStatusFlagsIncludeUntracked.rawValue |
                GTRepositoryStatusFlagsRecurseUntrackedDirectories.rawValue
    let options = [GTRepositoryStatusOptionsFlagsKey: UInt(flags)]
    
    try? gtRepo.enumerateFileStatus(options: options) {
      (headToIndex, indexToWorking, _) in
      guard let delta = headToIndex ?? indexToWorking
      else { return }
      let stagedChange = headToIndex.map { DeltaStatus(delta: $0.status) }
                         ?? DeltaStatus.unmodified
      let unstagedChange = indexToWorking.map { DeltaStatus(delta: $0.status) }
                           ?? DeltaStatus.unmodified
      let change = FileStagingChange(path: delta.oldFile?.path ?? "",
                               destinationPath: delta.newFile?.path ?? "",
                               change: stagedChange,
                               unstagedChange: unstagedChange)
      
      result.append(change)
    }
    return result
  }
  
  // Returns a file delta from a given diff.
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
  
  // Stages the given file to the index.
  @objc(stageFile:error:)
  func stage(file: String) throws
  {
    let fullPath = file.hasPrefix("/") ? file :
          repoURL.path.appending(pathComponent: file)
    let exists = FileManager.default.fileExists(atPath: fullPath)
    let args = [exists ? "add" : "rm", file]
    
    _ = try executeGit(args: args, writes: true)
  }
  
  // Stages all modified files.
  func stageAllFiles() throws
  {
    _ = try executeGit(args: ["add", "--all"], writes: true)
  }
  
  // Unstages all stages files.
  func unstage(file: String) throws
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
    
    outputBlock.map { $0(outputString) }
  }
}
