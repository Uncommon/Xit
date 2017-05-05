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

// TODO: Eliminate use of XTFileChange in ObjC code
class FileChange
{
  let path: String
  let change, unstagedChange: XitChange
  
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
  
  // Returns the changes for the given commit.
  @objc(changesForRef:parent:)
  func changes(for ref: String, parent parentSHA: String?) -> [XTFileChange]
  {
    guard ref != XTStagingSHA
    else { return stagingChanges() }
    
    guard let commit = (try? gtRepo.lookUpObject(byRevParse: ref)) as? GTCommit,
          let sha = commit.sha
    else { return [] }
    
    let parentSHA = parentSHA ?? commit.parents.first?.sha
    let diff = self.diff(forSHA: sha, parent: parentSHA)
    var result = [XTFileChange]()
    
    diff?.enumerateDeltas {
      (delta, _) in
      if delta.type != .unmodified {
        let change = XTFileChange()
        
        change.path = delta.newFile.path
        change.change = XitChange(delta: delta.type)
        result.append(change)
      }
    }
    return result
  }
  
  func stagingChanges() -> [XTFileChange]
  {
    var result = [XTFileStaging]()
    let options = [GTRepositoryStatusOptionsFlagsKey:
                   UInt(GTRepositoryStatusFlagsIncludeUntracked.rawValue)]
    
    try? gtRepo.enumerateFileStatus(options: options) {
      (headToIndex, indexToWorking, _) in
      let change = XTFileStaging()
      
      if let delta = headToIndex ?? indexToWorking {
        change.path = delta.oldFile?.path ?? ""
        change.destinationPath = delta.newFile?.path ?? ""
      }
      change.change = headToIndex.map { XitChange(delta: $0.status) }
                      ?? XitChange.unmodified
      change.unstagedChange = indexToWorking.map { XitChange(delta: $0.status) }
                              ?? XitChange.unmodified
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
  func _delta(from diff: GTDiff, path: String) -> XTDiffDelta?
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
  
  // Returns a file diff for a given commit.
  func _diff(for path: String,
             commitSHA sha: String,
             parentSHA: String?) -> XTDiffDelta?
  {
    guard let diff = self.diff(forSHA: sha, parent: parentSHA)
    else { return nil }
    
    return _delta(from: diff, path: path)
  }
  
  // Stages the given file to the index.
  func _stage(file: String) throws
  {
    let fullPath = file.hasPrefix("/") ? file :
          repoURL.path.appending(pathComponent:file)
    let exists = FileManager.default.fileExists(atPath: fullPath)
    let args = [exists ? "add" : "rm", file]
    
    try executeGit(withArgs: args, writes: true)
  }
  
  // Stages all modified files.
  func _stageAllFiles() throws
  {
    try executeGit(withArgs: ["add", "--all"], writes: true)
  }
  
  // Unstages all stages files.
  func _unstage(file: String) throws
  {
    let args = hasHeadReference ? ["reset", "-q", "HEAD", file]
                                : ["rm", "--cached", file]
    
    try executeGit(withArgs: args, writes: true)
  }
  
  // Creates a new commit with the given message.
  func _commit(message: String, amend: Bool,
               outputBlock: ((String) -> Void)?) throws
  {
    var args = ["commit", "-F", "-"]
    
    if amend {
      args.append("--amend")
    }
    
    let output = try executeGit(withArgs: args,
                                withStdIn: message, writes: true)
    let outputString = String(data: output, encoding: .utf8) ?? ""
    
    outputBlock.map { $0(outputString) }
  }
}
