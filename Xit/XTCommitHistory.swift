import Foundation


class CommitEntry: Equatable {
  let commit: CommitType
  var connections = [CommitConnection]()
  
  init(commit: CommitType)
  {
    self.commit = commit
  }
}

func == (left: CommitEntry, right: CommitEntry) -> Bool
{
  return left.commit.SHA == right.commit.SHA
}


/// A connection line between commits in the history list.
struct CommitConnection: Equatable {
  let parentSHA, childSHA: String
  let colorIndex: UInt
}

func == (left: CommitConnection, right: CommitConnection) -> Bool
{
  return (left.parentSHA == right.parentSHA) &&
         (left.childSHA == right.childSHA) &&
         (left .colorIndex == right.colorIndex)
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
    -> ([CommitEntry], [(commit: CommitType, after: CommitType)], [String])
  {
    var commit = startCommit
    var result = [CommitEntry(commit: startCommit)]
    var registeredParentSHAs = [String]()
    var queue = [(commit: CommitType, after: CommitType)]()
    
    while let firstParentSHA = commit.parentSHAs.first {
      for (index, parentSHA) in commit.parentSHAs.enumerate() {
        if commitLookup[parentSHA] != nil {
          registeredParentSHAs.append(parentSHA)
        } else if index > 0,
           let parentCommit = repository.commit(forSHA: parentSHA) {
          queue.append((parentCommit, commit))
        }
      }
      
      guard let parentCommit = repository.commit(forSHA: firstParentSHA)
      else {
        NSLog("Aborting branch, parent not found: \(firstParentSHA)")
        break
      }

      if !registeredParentSHAs.isEmpty {
        queue.append((parentCommit, commit))
        break
      }
      
      result.append(CommitEntry(commit: parentCommit))
      commit = parentCommit
    }
    
    return (result, queue, registeredParentSHAs)
  }
  
  /// Adds new commits to the list.
  func process(startCommit: CommitType, afterCommit: CommitType?)
  {
    guard let startSHA = startCommit.SHA where
          commitLookup[startSHA] == nil
    else { return }
    
    let (branchEntries, secondaryParents, insertBeforeSHAs) =
        self.branchEntries(startCommit)
    
    for branchEntry in branchEntries {
      if let sha = branchEntry.commit.SHA {
        commitLookup[sha] = branchEntry
      }
    }
    
    let afterIndex = afterCommit.flatMap(
        { commit in entries.indexOf({ $0.commit.SHA == commit.SHA }) })
    
    if let insertBeforeIndex = insertBeforeSHAs.flatMap(
           { sha in entries.indexOf({ $0.commit.SHA == sha }) }).sort().first {
      if let afterIndex = afterIndex where
         afterIndex < insertBeforeIndex {
        entries.insertContentsOf(branchEntries, at: afterIndex + 1)
      }
      else {
        entries.insertContentsOf(branchEntries, at: insertBeforeIndex)
      }
    }
    else if
       let lastSecondarySHA = secondaryParents.last?.after.SHA,
       let lastSecondaryEntry = commitLookup[lastSecondarySHA],
       let lastSecondaryIndex = entries.indexOf(
          { return $0.commit.SHA == lastSecondaryEntry.commit.SHA }) {
      entries.insertContentsOf(branchEntries, at: lastSecondaryIndex)
    }
    else if let afterIndex = afterIndex {
      entries.insertContentsOf(branchEntries, at: afterIndex + 1)
    }
    else {
      entries.appendContentsOf(branchEntries)
    }
  
    for (parent, after) in secondaryParents.reverse() {
      process(parent, afterCommit: after)
    }
  }
  
  
  /// Creates the connections to be drawn between commits.
  func connectCommits()
  {
    var connections = [CommitConnection]()
    var nextColorIndex: UInt = 0
    
    for entry in entries {
      guard let commitSHA = entry.commit.SHA
      else { continue }
      
      let incomingIndex = connections.indexOf({ $0.parentSHA == commitSHA })
      let incomingColor: UInt? = (incomingIndex != nil)
          ? connections[incomingIndex!].colorIndex
          : nil
      
      if let firstParentSHA = entry.commit.parentSHAs.first {
        let newConnection = CommitConnection(parentSHA: firstParentSHA,
                                             childSHA: commitSHA,
                                             colorIndex: incomingColor ??
                                                         nextColorIndex++)
        let insertIndex = (incomingIndex != nil)
            ? incomingIndex! + 1
            : connections.endIndex
        
        connections.insert(newConnection, atIndex: insertIndex)
      }
      
      // Add new connections for the commit's parents
      for parentSHA in entry.commit.parentSHAs.dropFirst() {
        connections.append(CommitConnection(parentSHA: parentSHA,
                                            childSHA: commitSHA,
                                            colorIndex: nextColorIndex++))
      }
      
      entry.connections = connections
      connections = connections.filter({ $0.parentSHA != commitSHA })
    }
  }
}
