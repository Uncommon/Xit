import Cocoa

public class XTStash: NSObject {

  var repo: XTRepository
  var mainCommit: GTCommit
  var indexCommit, untrackedCommit: GTCommit?
  private var cachedChanges: [XTFileChange]?
  
  init(repo: XTRepository, index: UInt)
  {
    self.repo = repo
    self.mainCommit = repo.commitForStashAtIndex(index)
    if self.mainCommit.parents.count > 0 {
      self.indexCommit = self.mainCommit.parents[1]
      if self.mainCommit.parents.count > 1 {
        self.untrackedCommit = self.mainCommit.parents[2]
      }
    }
  }
  
  func changes() -> [XTFileChange]
  {
    if let changes = self.cachedChanges {
      return changes
    }
    
    let parents = mainCommit.parents
    let stagedChanges = (indexCommit == nil) ? [] :
        repo.changesForRef(parents[1].SHA!, parent: nil)
    var unstagedChanges = repo.changesForRef(mainCommit.SHA!, parent: nil)
    
    if parents.count >= 2 {
      unstagedChanges.appendContentsOf(
          repo.changesForRef(parents[2].SHA!, parent: nil))
    }
    // Unstaged statuses aren't set because these are coming out of commits,
    // so they all have to be switched.
    for unstaged in unstagedChanges {
      unstaged.unstagedChange = unstaged.change
      unstaged.change = XitChangeUnmodified
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
  
  private func headBlobForPath(path: String) -> GTBlob?
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
    let headBlob = self.headBlobForPath(path)
    if let untrackedEntry = try? self.untrackedCommit?.tree?.entryWithPath(path) {
      guard let untrackedBlob = try? untrackedEntry?.GTObject() as? GTBlob
      else { return nil }
      
      return try? XTDiffDelta(fromBlob: headBlob, forPath: path,
                              toBlob: untrackedBlob, forPath: path,
                              options: nil)
    }
    if let unstagedEntry = try? self.mainCommit.tree?.entryWithPath(path) {
      guard let unstagedBlob = try? unstagedEntry?.GTObject() as? GTBlob
      else { return nil }
      
      return try? XTDiffDelta(fromBlob: headBlob, forPath: path,
                              toBlob: unstagedBlob, forPath: path,
                              options: nil)
    }
    return nil
  }
}
