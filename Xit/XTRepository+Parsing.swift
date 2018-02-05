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
  
  public override func isEqual(_ object: Any?) -> Bool
  {
    if let otherChange = object as? FileChange {
      return otherChange.path == path &&
             otherChange.change == change &&
             otherChange.unstagedChange == unstagedChange
    }
    return false
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
    
    outputBlock?(outputString)
  }
}
