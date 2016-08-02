import Foundation


class CommitEntry: Equatable {
  let commit: CommitType
  var children = [CommitEntry]()
  
  init(commit: CommitType)
  {
    self.commit = commit
  }
}

func == (left: CommitEntry, right: CommitEntry) -> Bool
{
  return left.commit.SHA == right.commit.SHA
}


class XTCommitHistory {
  
  let repository: RepositoryType
  
  var commitLookup = [String: CommitEntry]()
  var entries = [CommitEntry]()
  
  init(repository: RepositoryType)
  {
    self.repository = repository
  }
  
  /// Creates a list of commits for the branch starting at the given commit, and
  /// also a list of secondary parents that may start other branches.
  func branchEntries(startCommit: CommitType)
    -> ([CommitEntry], [(commit: CommitType, after: CommitType)])
  {
    var commit = startCommit
    var result = [CommitEntry(commit: startCommit)]
    var secondaryParents = [(commit: CommitType, after: CommitType)]()
    
    while !commit.parentSHAs.isEmpty {
      let parentSHA = commit.parentSHAs.first!
      
      if commit.parentSHAs.count > 0 {
        let parentSHAs = commit.parentSHAs[1..<commit.parentSHAs.count]
        var existingParent: CommitType? = nil
        
        secondaryParents.appendContentsOf(parentSHAs.flatMap({ (parentSHA) in
          // If a parent is already entered, stop now.
          if let parentEntry = commitLookup[parentSHA] {
            existingParent = parentEntry.commit
            return nil
          }
          guard let parentCommit = self.repository.commit(forSHA: parentSHA)
          else { return nil }
          return (parentCommit, commit)
        }))
        if let existingParent = existingParent {
          if let firstParent =
              self.repository.commit(forSHA: commit.parentSHAs[0]) {
            // Add the current commit's first parent so we can pick up
            // after adding the current batch.
            secondaryParents.append((firstParent, existingParent))
          }
          break
        }
      }
      
      // If the parent SHA is already in the lookup,
      // then it's the end of the branch.
      if commitLookup[parentSHA] != nil {
        break
      }
      
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
  func process(startCommit: CommitType, afterCommit: CommitType?)
  {
    guard let startSHA = startCommit.SHA where
          commitLookup[startSHA] == nil
    else { return }
    
    let (branchEntries, secondaryParents) = self.branchEntries(startCommit)
    
    for branchEntry in branchEntries {
      if let sha = branchEntry.commit.SHA {
        commitLookup[sha] = branchEntry
      }
    }
    if let afterCommit = afterCommit,
       let afterIndex = entries.indexOf(
          { return $0.commit.SHA == afterCommit.SHA }) {
      entries.insertContentsOf(branchEntries, at: afterIndex + 1)
    }
    else {
      entries.appendContentsOf(branchEntries)
    }
    
    for (parent, after) in secondaryParents {
      process(parent, afterCommit: after)
    }
  }
  
}
