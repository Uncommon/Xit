import Cocoa
import FakedMacro

@Faked
public protocol Stash: AnyObject
{
  associatedtype Commit: Xit.Commit

  var message: String? { get }
  var mainCommit: Commit? { get }
  var indexCommit: Commit? { get }
  var untrackedCommit: Commit? { get }
  
  func indexChanges() -> [FileChange]
  func workspaceChanges() -> [FileChange]
  func stagedDiffForFile(_ path: String) -> PatchMaker.PatchResult?
  func unstagedDiffForFile(_ path: String) -> PatchMaker.PatchResult?
}

/// Wraps a stash to preset a unified list of file changes.
public final class GitStash: Stash
{
  public typealias ID = GitOID
  
  unowned var repo: XTRepository
  public var message: String?
  public private(set) var mainCommit: GitCommit?
  public private(set) var indexCommit, untrackedCommit: GitCommit?
  private var cachedIndexChanges, cachedWorkspaceChanges: [FileChange]?

  init(repo: XTRepository, index: UInt, message: String?)
  {
    self.repo = repo
    self.message = message
    
    if let mainCommit = repo.commitForStash(at: index) as? GitCommit {
      self.mainCommit = mainCommit
      if mainCommit.parentOIDs.count > 1 {
        // Should be able to use repo.commit() directly...
        self.indexCommit = repo.commit(forOID: mainCommit.parentOIDs[1])
        if mainCommit.parentOIDs.count > 2 {
          self.untrackedCommit = repo.commit(forOID: mainCommit.parentOIDs[2])
        }
      }
    }
  }

  public func indexChanges() -> [FileChange]
  {
    if let changes = cachedIndexChanges {
      return changes
    }
    
    let changes = indexCommit.map { repo.changes(for: $0.id, parent: nil) } ?? []
    
    cachedIndexChanges = changes
    return changes
  }
  
  public func workspaceChanges() -> [FileChange]
  {
    if let changes = cachedWorkspaceChanges {
      return changes
    }
    
    guard let mainCommit = self.mainCommit
    else { return [] }
    var changes = repo.changes(for: mainCommit.id, parent: indexCommit?.id)
    
    if let untrackedCommit = self.untrackedCommit {
      let untrackedChanges = repo.changes(for: untrackedCommit.id, parent: nil)
      
      changes.append(contentsOf: untrackedChanges)
    }
    
    changes.sort { $0.path.compare($1.path) == .orderedAscending }
    self.cachedWorkspaceChanges = changes
    return changes
  }

  func headBlobForPath(_ path: String) -> (any Blob)?
  {
    guard let mainCommit = self.mainCommit,
          let parentOID = mainCommit.parentOIDs.first,
          let parent = GitCommit(oid: parentOID,
                                 repository: mainCommit.repository),
          let headEntry = parent.tree?.entry(path: path)
    else { return nil }
    
    return headEntry.object as? any Blob
  }

  public func stagedDiffForFile(_ path: String) -> PatchMaker.PatchResult?
  {
    guard let indexCommit = self.indexCommit
    else { return nil }
    guard repo.isTextFile(path, context: .commit(indexCommit))
    else { return .binary }
    guard let indexEntry = indexCommit.tree?.entry(path: path),
          let indexBlob = indexEntry.object as? any Blob
    else { return nil }
    let headBlob = self.headBlobForPath(path)
    
    return .diff(PatchMaker(from: PatchMaker.SourceType(headBlob),
                             to: PatchMaker.SourceType(indexBlob),
                             path: path))
  }

  public func unstagedDiffForFile(_ path: String) -> PatchMaker.PatchResult?
  {
    guard let indexCommit = self.indexCommit
    else { return nil }

    var indexBlob: (any Blob)?
    
    if let indexEntry = indexCommit.tree?.entry(path: path) {
      if !repo.isTextFile(path, context: .commit(indexCommit)) {
        return .binary
      }
      indexBlob = indexEntry.object as? any Blob
    }
    
    if let untrackedCommit = self.untrackedCommit,
       let untrackedEntry = untrackedCommit.tree?.entry(path: path) {
      if !repo.isTextFile(path, context: .commit(untrackedCommit)) {
        return .binary
      }
      guard let untrackedBlob = untrackedEntry.object as? any Blob
      else { return nil }
      
      return .diff(PatchMaker(from: PatchMaker.SourceType(indexBlob),
                               to: PatchMaker.SourceType(untrackedBlob),
                               path: path))
    }
    if let mainCommit = self.mainCommit,
       let unstagedEntry = mainCommit.tree?.entry(path: path) {
      guard let unstagedBlob = unstagedEntry.object as? any Blob
      else { return nil }
      
      return .diff(PatchMaker(from: PatchMaker.SourceType(indexBlob),
                               to: PatchMaker.SourceType(unstagedBlob),
                               path: path))
    }
    return nil
  }
}
