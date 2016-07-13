import Cocoa

/**
 * Wraps a stash to preset a unified list of file changes.
 */
public class XTStash: NSObject {

var repo: XTRepository
var message: String?
var mainCommit: GTCommit
var indexCommit, untrackedCommit: GTCommit?
private var cachedChanges: [XTFileChange]?

init(repo: XTRepository, index: UInt, message: String?)
{
  self.repo = repo
  self.message = message
  self.mainCommit = repo.commitForStashAtIndex(index)!
  if self.mainCommit.parents.count > 1 {
    self.indexCommit = self.mainCommit.parents[1]
    if self.mainCommit.parents.count > 2 {
      self.untrackedCommit = self.mainCommit.parents[2]
    }
  }
}

func changes() -> [XTFileChange]
{
  if let changes = cachedChanges {
    return changes
  }
  
  let stagedChanges = (indexCommit == nil) ? [] :
      repo.changesForRef(indexCommit!.SHA!, parent: nil) ?? [XTFileChange]()
  var unstagedChanges = repo.changesForRef(mainCommit.SHA!,
                                           parent: indexCommit?.SHA) ??
                        [XTFileChange]()
  
  if let untrackedCommit = self.untrackedCommit {
    if let untrackedChanges = repo.changesForRef(untrackedCommit.SHA!,
                                                 parent: nil) {
      unstagedChanges.appendContentsOf(untrackedChanges)
    }
  }
  // Unstaged statuses aren't set because these are coming out of commits,
  // so they all have to be switched.
  for unstaged in unstagedChanges {
    unstaged.unstagedChange = unstaged.change
    unstaged.change = .Unmodified
  }
  
  let unstagedPaths = unstagedChanges.map({ $0.path })
  var unstagedDict = [String: XTFileChange]()
  
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
  
  var changes = [XTFileChange](unstagedDict.values)
  
  changes.sortInPlace { $0.path.compare($1.path) == .OrderedAscending }
  self.cachedChanges = changes
  return changes
}

func headBlobForPath(path: String) -> GTBlob?
{
  guard let headEntry = try? mainCommit.parents[0].tree?.entryWithPath(path),
        let object = try? headEntry?.GTObject()
  else { return nil }
  return (object as? GTBlob?)!
}

func stagedDiffForFile(path: String) -> XTDiffDelta?
{
  guard let indexCommit = self.indexCommit,
        let indexEntry = try? indexCommit.tree?.entryWithPath(path),
        let indexBlob = try? indexEntry!.GTObject() as? GTBlob
  else { return nil }
  let headBlob = self.headBlobForPath(path)
  
  return try? XTDiffDelta(fromBlob: headBlob, forPath: path,
                          toBlob: indexBlob, forPath: path, options: nil)
}

func unstagedDiffForFile(path: String) -> XTDiffDelta?
{
  guard let indexCommit = self.indexCommit
  else { return nil }

  var indexBlob: GTBlob? = nil
  
  if let indexEntry = try? indexCommit.tree!.entryWithPath(path) {
    let object = try? indexEntry.GTObject()
    
    indexBlob = object as? GTBlob
  }
  
  if let untrackedCommit = self.untrackedCommit,
     let untrackedEntry = try? untrackedCommit.tree?.entryWithPath(path) {
    guard let untrackedBlob = try? untrackedEntry!.GTObject() as? GTBlob
    else { return nil }
    
    return try? XTDiffDelta(fromBlob: indexBlob, forPath: path,
                            toBlob: untrackedBlob, forPath: path,
                            options: nil)
  }
  if let unstagedEntry = try? self.mainCommit.tree?.entryWithPath(path) {
    guard let unstagedBlob = try? unstagedEntry?.GTObject() as? GTBlob
    else { return nil }
    
    return try? XTDiffDelta(fromBlob: indexBlob, forPath: path,
                            toBlob: unstagedBlob, forPath: path,
                            options: nil)
  }
  return nil
}

}
