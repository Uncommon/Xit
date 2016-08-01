import Cocoa


struct Commit {
  var sha: String
  var parentSHAs: [String]
}

func == (left: Commit, right: Commit) -> Bool
{
  // No need to compare the parents
  return left.sha == right.sha
}


class CommitEntry {
  let commit: Commit
  var children = [Commit]()
  
  init(commit: Commit)
  {
    self.commit = commit
  }
}

func == (left: CommitEntry, right: CommitEntry) -> Bool
{
  return left.commit == right.commit
}


class Repository {
  
  func commit(forSHA sha: String) -> Commit?
  {
    return nil
  }
}


class CommitHistory {

  let repository: Repository

  var commitLookup = [String: CommitEntry]()
  var entries = [CommitEntry]()
  
  init(repository: Repository)
  {
    self.repository = repository
  }
  
  /// Adds a commit to the history, either at the end or after its
  /// first parent.
  /// - returns: false if the commit is already in the history.
  func add(commit: Commit, toParent parent: Commit?) -> Bool
  {
    guard commitLookup[commit.sha] == nil
    else { return false }
    
    let entry = CommitEntry(commit: commit)
    
    commitLookup[commit.sha] = entry
    
    // Too do: find a more efficient way of finding the parent. Maybe
    // keep a recently added list, since those would be likely candidates.
    if let firstParentSHA = commit.parentSHAs.first,
       let parentEntry = commitLookup[firstParentSHA],
       let parentIndex = entries.indexOf({ $0 == parentEntry }) {
      entries.insert(entry, atIndex: parentIndex+1)
    }
    else {
      NSLog("Parent not found for \(commit.sha)")
    }
    entries.append(entry)
    return true;
  }

  /// Adds a commit and all of its parents to the list.
  func process(startCommit: Commit, parent: Commit?)
  {
    var parent = parent
    var commit = startCommit
    var parentStack = [(Commit, Commit)]()
    
    while add(commit, toParent: parent) && !commit.parentSHAs.isEmpty {
      if commit.parentSHAs.count > 1 {
        let parents = commit.parentSHAs[1..<commit.parentSHAs.count]
        
        parentStack.appendContentsOf(parents.flatMap({
          guard let parentCommit = self.repository.commit(forSHA: $0)
          else { return nil }
          return (commit, parentCommit)
        }))
      }
      if !commit.parentSHAs.isEmpty,
         let next = repository.commit(forSHA: commit.parentSHAs[0]) {
        parent = commit
        commit = next
      }
      else {
        break
      }
    }
    for (commit, parent) in parentStack { // need to reverse order?
      process(commit, parent: parent)
    }
  }

}
