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
  
  /// Creates a list of commits for the branch starting at the given commit, and also a list of
  /// secondary parents that may start other branches.
  func branchEntries(startCommit: Commit) -> ([CommitEntry], [(commit: Commit, parent: Commit)])
  {
    var commit = startCommit
    var result = [CommitEntry]()
    var secondaryParents = [(commit: Commit, parent: Commit)]()
    
    while !commit.parentSHAs.isEmpty {
      if commit.parentSHAs.count > 0 {
        let shas = commit.parentSHAs[1..<commit.parentSHAs.count]
        
        secondaryParents.appendContentsOf(shas.flatMap({ (parentSHA) in
          guard let parentCommit = self.repository.commit(forSHA: parentSHA)
          else { return nil }
          return (commit, parentCommit)
        }))
      }
      
      // If the parent SHA is already in the lookup, then it's the end of the branch.
      guard let parentSHA = commit.parentSHAs.first where
            commitLookup[parentSHA] == nil
      else { break }
      
      guard let parentCommit = repository.commit(forSHA: parentSHA)
      else {
        NSLog("Aborting branch, parent not found: \(parentSHA)")
        break
      }
      
      result.append(CommitEntry(commit: parentCommit))
      commit = parentCommit
    }
    return (result, secondaryParents)
  }
  
  /// Adds new commits to the list.
  func process(startCommit: Commit, afterCommit: Commit?)
  {
    guard commitLookup[startCommit.sha] == nil
    else { return }
    
    let (branchEntries, secondaryParents) = self.branchEntries(startCommit)
    
    branchEntries.forEach({ entry in commitLookup[entry.commit.sha] = entry })
    if let afterCommit = afterCommit,
       let afterIndex = entries.indexOf({ return $0.commit.sha == afterCommit.sha }) {
      entries.insertContentsOf(branchEntries, at: afterIndex + 1)
    }
    else {
      entries.appendContentsOf(branchEntries)
    }
    
    for (commit, parent) in secondaryParents {
      process(parent, afterCommit: commit)
    }
  }

}
