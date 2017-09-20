import Foundation

extension XitChange
{
  init(delta: GTDeltaType)
  {
    guard let change = XitChange(rawValue: UInt(delta.rawValue))
    else {
      self = .unmodified
      return
    }
    
    self = change
  }
}

struct WorkspaceFileStatus
{
  let change, unstagedChange: XitChange
}

// Has to inherit from NSObject so NSTreeNode can use it to sort
class FileChange: NSObject
{
  @objc var path: String
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
  // A path:status dictionary for locally changed files.
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
  
  func stagingChanges() -> [FileChange]
  {
    var result = [FileStaging]()
    let flags = GTRepositoryStatusFlagsIncludeUntracked.rawValue |
                GTRepositoryStatusFlagsRecurseUntrackedDirectories.rawValue
    let options = [GTRepositoryStatusOptionsFlagsKey: UInt(flags)]
    
    try? gtRepo.enumerateFileStatus(options: options) {
      (headToIndex, indexToWorking, _) in
      guard let delta = headToIndex ?? indexToWorking
      else { return }
      let stagedChange = headToIndex.map { XitChange(delta: $0.status) }
                         ?? XitChange.unmodified
      let unstagedChange = indexToWorking.map { XitChange(delta: $0.status) }
                           ?? XitChange.unmodified
      let change = FileStaging(path: delta.oldFile?.path ?? "",
                               destinationPath: delta.newFile?.path ?? "",
                               change: stagedChange,
                               unstagedChange: unstagedChange)
      
      result.append(change)
    }
    return result
  }
  
  static let textNames = ["AUTHORS", "CONTRIBUTING", "COPYING", "LICENSE",
                          "Makefile", "README"]
  
  // Returns true if the file seems to be text, based on its name.
  func isTextFile(_ path: String, commit: String) -> Bool
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
          repoURL.path.appending(pathComponent:file)
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
