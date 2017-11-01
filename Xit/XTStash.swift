import Cocoa

public protocol Stash: class
{
  var message: String? { get }
  var mainCommit: Commit? { get }
  var indexCommit: Commit? { get }
  var untrackedCommit: Commit? { get }
  
  func changes() -> [FileChange]
  func stagedDiffForFile(_ path: String) -> PatchMaker.PatchResult?
  func unstagedDiffForFile(_ path: String) -> PatchMaker.PatchResult?
}

/// Wraps a stash to preset a unified list of file changes.
public class XTStash: NSObject, Stash
{
  typealias Repo = CommitStorage & FileContents & FileStaging & Stashing
  
  unowned var repo: Repo
  public var message: String?
  public var mainCommit: Commit?
  public var indexCommit, untrackedCommit: Commit?
  private var cachedChanges: [FileChange]?

  init(repo: Repo, index: UInt, message: String?)
  {
    self.repo = repo
    self.message = message
    
    if let mainCommit = repo.commitForStash(at: index) {
      self.mainCommit = mainCommit
      if mainCommit.parentOIDs.count > 1 {
        self.indexCommit = repo.commit(forOID: mainCommit.parentOIDs[1])
        if mainCommit.parentOIDs.count > 2 {
          self.untrackedCommit = repo.commit(forOID: mainCommit.parentOIDs[2])
        }
      }
    }
  }

  public func changes() -> [FileChange]
  {
    if let changes = cachedChanges {
      return changes
    }
    
    guard var unstagedChanges = mainCommit?.sha.map({
        repo.changes(for: $0, parent: indexCommit?.oid) })
    else { return [] }
    let stagedChanges = indexCommit.map { repo.changes(for: $0.sha!,
                                                       parent: nil) }
                        ?? []
    
    if let untrackedCommit = self.untrackedCommit {
      let untrackedChanges = repo.changes(for: untrackedCommit.sha!, parent: nil)
      
      unstagedChanges.append(contentsOf: untrackedChanges)
    }
    // Unstaged statuses aren't set because these are coming out of commits,
    // so they all have to be switched.
    for unstaged in unstagedChanges {
      unstaged.unstagedChange = unstaged.change
      unstaged.change = .unmodified
    }
    
    let unstagedPaths = unstagedChanges.map({ $0.path })
    var unstagedDict = [String: FileChange]()
    
    // Apparently the closest thing to dictionaryWithObjects:forKeys:
    for (path, fileChange) in zip(unstagedPaths, unstagedChanges) {
      unstagedDict[path] = fileChange
    }
    
    for staged in stagedChanges {
      if let change = unstagedDict[staged.path] {
        change.change = staged.change
      }
      else {
        unstagedDict[staged.path] = staged
      }
    }
    
    var changes = [FileChange](unstagedDict.values)
    
    changes.sort { $0.path.compare($1.path) == .orderedAscending }
    self.cachedChanges = changes
    return changes
  }

  func headBlobForPath(_ path: String) -> Blob?
  {
    guard let mainCommit = self.mainCommit as? XTCommit,
          let parentOID = mainCommit.parentOIDs.first,
          let parent = XTCommit(oid: parentOID, repository: mainCommit.repository),
          let headEntry = parent.tree?.entry(path: path)
    else { return nil }
    
    return headEntry.object as? Blob
  }

  public func stagedDiffForFile(_ path: String) -> PatchMaker.PatchResult?
  {
    guard let indexCommit = self.indexCommit as? XTCommit
    else { return nil }
    guard repo.isTextFile(path, commitOID: indexCommit.oid)
    else { return .binary }
    guard let indexEntry = indexCommit.tree?.entry(path: path),
          let indexBlob = indexEntry.object as? Blob
    else { return nil }
    let headBlob = self.headBlobForPath(path)
    
    return .diff(PatchMaker(from: PatchMaker.SourceType(headBlob),
                             to: PatchMaker.SourceType(indexBlob),
                             path: path))
  }

  public func unstagedDiffForFile(_ path: String) -> PatchMaker.PatchResult?
  {
    guard let indexCommit = self.indexCommit as? XTCommit
    else { return nil }

    var indexBlob: Blob? = nil
    
    if let indexEntry = indexCommit.tree!.entry(path: path) {
      if !repo.isTextFile(path, commitOID: indexCommit.oid) {
        return .binary
      }
      indexBlob = indexEntry.object as? Blob
    }
    
    if let untrackedCommit = self.untrackedCommit as? XTCommit,
       let untrackedEntry = untrackedCommit.tree?.entry(path: path) {
      if !repo.isTextFile(path, commitOID: untrackedCommit.oid) {
        return .binary
      }
      guard let untrackedBlob = untrackedEntry.object as? Blob
      else { return nil }
      
      return .diff(PatchMaker(from: PatchMaker.SourceType(indexBlob),
                               to: PatchMaker.SourceType(untrackedBlob),
                               path: path))
    }
    if let mainCommit = self.mainCommit as? XTCommit,
       let unstagedEntry = mainCommit.tree?.entry(path: path) {
      guard let unstagedBlob = unstagedEntry.object as? Blob
      else { return nil }
      
      return .diff(PatchMaker(from: PatchMaker.SourceType(indexBlob),
                               to: PatchMaker.SourceType(unstagedBlob),
                               path: path))
    }
    return nil
  }
}
