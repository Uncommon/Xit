import Foundation
import UniformTypeIdentifiers
import Clibgit2

public enum FileContext
{
  case commit(any Commit)
  case index
  case workspace
}

// MARK: FileContents
extension XTRepository: FileContents
{
  static let textNames = ["AUTHORS", "CONTRIBUTING", "COPYING", "LICENSE",
                          "Makefile", "README"]
  
  static func isTextExtension(_ name: String) -> Bool
  {
    let ext = (name as NSString).pathExtension
    guard !ext.isEmpty,
          let type = UTType(filenameExtension: ext)
    else { return false }

    return type.conforms(to: .text)
  }
  
  /// Returns true if the file seems to be text, based on its name or its content.
  /// - parameter path: File path relative to the repository
  /// - parameter context: Where to look for the specified file
  public func isTextFile(_ path: String, context: FileContext) -> Bool
  {
    let name = (path as NSString).lastPathComponent
    guard !name.isEmpty
    else { return false }
    
    if XTRepository.textNames.contains(name) {
      return true
    }
    if XTRepository.isTextExtension(name) {
      return true
    }
    
    switch context {
      case .commit(let commit):
        if let entry = (commit as? GitCommit)?.tree?.entry(path: path),
           let blob = entry.object as? GitBlob {
          return !blob.isBinary
        }
      case .index:
        if let oid = GitIndex(repository: gitRepo)?.entry(at: path)?.oid,
           let blob = GitBlob(repository: gitRepo, oid: oid) {
          return !blob.isBinary
        }
      case .workspace:
        let url = self.fileURL(path)
        guard let data = try? Data(contentsOf: url)
        else { return false }
        
        return !data.isBinary()
    }
    
    return false
  }
  
  public func contentsOfFile(path: String, at commit: any XitGit.Commit) -> Data?
  {
    guard let entry = (commit as? GitCommit)?.tree?.entry(path: path),
          let blob = entry.object as? GitBlob
    else { return nil }
    
    return blob.makeData()
  }
  
  public func contentsOfStagedFile(path: String) -> Data?
  {
    stagedBlob(file: path)?.withUnsafeBytes {
      Data($0)
    }
  }
  
  public func stagedBlob(file: String) -> GitBlob?
  {
    guard let index = GitIndex(repository: gitRepo),
          let entry = index.entry(at: file),
          let blob = GitBlob(repository: gitRepo,
                             oid: entry.oid)
    else { return nil }
    
    return blob
  }
  
  public func commitBlob(commit: GitCommit?, path: String) -> GitBlob?
  {
    commit?.tree?.entry(path: path)?.object as? GitBlob
  }
  
  public func fileBlob(ref: any ReferenceName, path: String) -> GitBlob?
  {
    commitBlob(commit: oid(forRef: ref).flatMap { commit(forOID: $0) },
               path: path)
  }
  
  public func fileBlob(oid: GitOID, path: String) -> GitBlob?
  {
    return commitBlob(commit: commit(forOID: oid), path: path)
  }
  
  /// Returns a file URL for a given relative path.
  public func fileURL(_ file: String) -> URL
  {
    return repoURL.appendingPathComponent(file)
  }
}

// MARK: FileDiffing
extension XTRepository: FileDiffing
{
  /// Returns a diff maker for a file at the specified commit, compared to the
  /// parent commit.
  public func diffMaker(forFile file: String,
                        commitOID: GitOID,
                        parentOID: GitOID?) -> PatchMaker.PatchResult?
  {
    guard let toCommit = commit(forOID: commitOID)
    else { return nil }
    
    let parentCommit = parentOID.flatMap { commit(forOID: $0) }
    guard isTextFile(file, context: .commit(toCommit)) ||
          parentCommit.map({ isTextFile(file, context: .commit($0)) }) ?? false
    else { return .binary }
    
    var fromSource = PatchMaker.SourceType.data(Data())
    var toSource = PatchMaker.SourceType.data(Data())
    
    if let toEntry = toCommit.tree?.entry(path: file),
       let toBlob = toEntry.object as? GitBlob {
      toSource = .blob(toBlob)
    }
    
    if let fromEntry = parentCommit?.tree?.entry(path: file),
       let fromBlob = fromEntry.object as? GitBlob {
      fromSource = .blob(fromBlob)
    }
    
    return .diff(PatchMaker(from: fromSource, to: toSource, path: file))
  }
  
  /// Returns a diff maker for a file in the index, compared to HEAD
  public func stagedDiff(file: String) -> PatchMaker.PatchResult?
  {
    guard isTextFile(file, context: .index)
    else { return .binary }
    
    guard let headRef = self.headRefName
    else { return nil }
    let indexBlob = stagedBlob(file: file)
    let headBlob = fileBlob(ref: headRef, path: file)
    
    return .diff(PatchMaker(from: PatchMaker.SourceType(headBlob),
                             to: PatchMaker.SourceType(indexBlob),
                             path: file))
  }
  
  /// Returns a diff maker for a file in the index, compared to HEAD-1.
  public func amendingStagedDiff(file: String) -> PatchMaker.PatchResult?
  {
    guard isTextFile(file, context: .index)
    else { return .binary }
    
    guard let headCommit = self.headCommit
    else { return nil }
    let blob = headCommit.parentOIDs.first
                         .flatMap { fileBlob(oid: $0, path: file) }
    let indexBlob = stagedBlob(file: file)

    return .diff(PatchMaker(from: PatchMaker.SourceType(blob),
                            to: PatchMaker.SourceType(indexBlob),
                            path: file))
  }
  
  /// Returns a diff maker for a file in the workspace, compared to the index.
  public func unstagedDiff(file: String) -> PatchMaker.PatchResult?
  {
    guard isTextFile(file, context: .workspace)
    else { return .binary }
    
    let url = self.repoURL.appendingPathComponent(file)
    let exists = FileManager.default.fileExists(atPath: url.path)
    
    do {
      let data = exists ? try Data(contentsOf: url) : Data()
      
      if let index = GitIndex(repository: gitRepo),
         let indexEntry = index.entry(at: file),
         let indexBlob = GitBlob.init(repository: gitRepo,
                                      oid: indexEntry.oid) {
        return .diff(PatchMaker(from: PatchMaker.SourceType(indexBlob),
                                 to: .data(data), path: file))
      }
      else {
        return .diff(PatchMaker(from: .data(Data()),
                                 to: .data(data),
                                 path: file))
      }
    }
    catch {
      return nil
    }
  }
  
  public func blame(for path: String,
                    from startOID: GitOID?,
                    to endOID: GitOID?) -> GitBlame?
  {
    GitBlame(repository: self, path: path, from: startOID, to: endOID)
  }
  
  public func blame(for path: String,
                    data fromData: Data?,
                    to endOID: GitOID?) -> GitBlame?
  {
    GitBlame(repository: self, path: path,
             data: fromData ?? Data(), to: endOID)
  }
}

public extension XTRepository
{
  /// Returns the diff for the referenced commit, compared to its first parent
  /// or to a specific parent.
  func diff(forOID oid: GitOID, parent parentOID: GitOID?) -> (any Diff)?
  {
    let key = oid.sha.rawValue.appending(parentOID?.sha.rawValue ?? "")
    
    if let diff = diffCache[key] {
      return diff
    }
    else {
      guard let commit = commit(forOID: oid)
      else { return nil }
      
      let parentOIDs = commit.parentOIDs
      let parentOID: GitOID? = parentOID == nil
            ? parentOIDs.first
            : parentOIDs.first { $0 == parentOID }
      let parentCommit = parentOID.flatMap { self.commit(forOID: $0) }
      
      guard let diff = GitDiff(oldTree: parentCommit?.tree,
                               newTree: commit.tree,
                               repository: gitRepo)
      else { return nil }
      
      diffCache[key] = diff
      return diff
    }
  }
  
  /// Applies the given patch hunk to the specified file in the index.
  /// - parameter path: Target file path
  /// - parameter hunk: Hunk to be applied
  /// - parameter stage: True if the change is being staged, falses if unstaged
  /// (the patch should be reversed)
  /// - throws: `Error.patchMismatch` if the patch can't be applied, or any
  /// errors from resultings stage/unstage actions.
  func patchIndexFile(path: String, hunk: any DiffHunk, stage: Bool) throws
  {
    guard let index = GitIndex(repository: gitRepo)
    else { throw RepoError.unexpected }
    
    if let entry = index.entry(at: path) {
      if (hunk.newStart == 1) || (hunk.oldStart == 1) {
        let status = try self.status(file: path)
        
        if stage {
          if status.0 == .deleted {
            try self.stage(file: path)
            return
          }
        }
        else {
          switch status.1 {
            case .added, .deleted:
              // If it's added/deleted in the index, and we're unstaging, then
              // the hunk must cover the whole file
              try unstage(file: path)
              return
            default:
              break
          }
        }
      }
      
      guard let blob = GitBlob(repository: gitRepo,
                               oid: entry.oid)
      else { throw RepoError.unexpected }
      
      try blob.withUnsafeBytes {
        (bytes) in
        guard let text = String(bytes: bytes, encoding: .utf8),
              let patchedText = hunk.applied(to: text, reversed: !stage)
        else { throw RepoError.patchMismatch }
        
        guard let patchedData = patchedText.data(using: .utf8)
        else { throw RepoError.unexpected }
        
        try index.add(data: patchedData, path: path)
      }
      try index.save()
      return
    }
    else {
      let status = try self.status(file: path)
      
      // Assuming the hunk covers the whole file
      if stage && status.0 == .untracked && hunk.newStart == 1 {
        try self.stage(file: path)
        return
      }
      else if !stage && (status.1 == .deleted) && (hunk.oldStart == 1) {
        try unstage(file: path)
        return
      }
    }
    throw RepoError.patchMismatch
  }
  
  class StatusCollection: BidirectionalCollection
  {
    let statusList: OpaquePointer?
    var tree: OpaquePointer?
  
    init(repo: XTRepository, head: (any XitGit.Commit)?)
    {
      let headTree = ((head as? GitCommit)?.tree)?.tree
      var options = git_status_options()
      
      git_status_init_options(&options, UInt32(GIT_STATUS_OPTIONS_VERSION))
      options.flags = GIT_STATUS_OPT_INCLUDE_UNTRACKED.rawValue |
                      GIT_STATUS_OPT_RECURSE_UNTRACKED_DIRS.rawValue
      if let tree = headTree {
        options.baseline = tree
      }
      else {
        tree = StatusCollection.emptyTree(repo: repo)
        options.baseline = tree
      }
      
      self.statusList = try? OpaquePointer.from {
        git_status_list_new(&$0, repo.gitRepo, &options)
      }
    }
    
    convenience init(repo: XTRepository)
    {
      self.init(repo: repo,
                head: repo.headOID
                          .flatMap { repo.commit(forOID: $0) })
    }
  
    static func emptyTree(repo: XTRepository) -> OpaquePointer?
    {
      guard let emptyOID = GitOID(sha: .emptyTree)
      else { return nil }
      
      return try? OpaquePointer.from {
        (tree) in
        emptyOID.withUnsafeOID { git_tree_lookup(&tree, repo.gitRepo, $0) }
      }
    }
  
    public subscript(position: Int) -> FileChange
    {
      guard let statusList = self.statusList,
            let entry = git_status_byindex(statusList, position)?.pointee,
            let delta = entry.head_to_index ?? entry.index_to_workdir
      else { return .init(path: "") }
      
      let path = String(cString: delta.pointee.old_file.path)
      let stagedChange = (entry.head_to_index?.pointee.status)
            .map { DeltaStatus(gitDelta: $0) } ?? .unmodified
      
      return .init(
          path: path,
          change: stagedChange)
    }
    
    public var startIndex: Int { 0 }
    public var endIndex: Int
    { statusList.map { git_status_list_entrycount($0) } ?? 0 }
    
    public func index(before i: Int) -> Int { return i - 1 }
    public func index(after i: Int) -> Int { return i + 1 }
    
    deinit
    {
      tree.map { git_tree_free($0) }
      statusList.map { git_status_list_free($0) }
    }
  }
  
  var stagingChanges: StatusCollection
  { .init(repo: self) }
  
  func amendingChanges(parent: GitCommit?) -> StatusCollection
  {
    .init(repo: self, head: parent)
  }
}
