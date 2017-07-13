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

  /// Returns the workspace changes compared to the given parent of HEAD.
  func stagingChanges(parent: XTCommit) -> [FileChange]
  {
    let workspaceChanges = stagingChanges
    guard let headSHA = self.headSHA,
          let parentSHA = parent.sha
    else { return Array(workspaceChanges) }
    let parentChanges = changes(for: headSHA, parent: parentSHA)
    var parentDict = [String: FileChange]()
    var result = [FileChange]()
    
    for change in parentChanges {
      parentDict[change.path] = change
    }
    for change in workspaceChanges {
      if let parentChange = parentDict[change.path] {
        change.change = parentChange.change
        parentDict[change.path] = nil
      }
      result.append(change)
    }
    result.append(contentsOf: parentDict.values)
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
