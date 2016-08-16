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
  
  /// The result of processing a segment of a branch.
  struct BranchResult {
    /// The commit entries collected for this segment.
    var entries: [CommitEntry]
    /// Other branches queued for processing.
    var queue: [(commit: CommitType, after: CommitType)]
  }
  
  init(repository: RepositoryType)
  {
    self.repository = repository
  }
  
  func reset()
  {
    commitLookup.removeAll()
    entries.removeAll()
  }
  
  /// Creates a list of commits for the branch starting at the given commit, and
  /// also a list of secondary parents that may start other branches. A branch
  /// segment ends when a commit has more than one parent, or its parent is
  /// already registered.
  func branchEntries(startCommit: CommitType) -> BranchResult
  {
    var commit = startCommit
    var result = [CommitEntry(commit: startCommit)]
    var queue = [(commit: CommitType, after: CommitType)]()
    
    while let firstParentSHA = commit.parentSHAs.first {
      for parentSHA in commit.parentSHAs.dropFirst() {
        if let parentCommit = repository.commit(forSHA: parentSHA) {
          queue.append((parentCommit, commit))
        }
      }
      
      guard commitLookup[firstParentSHA] == nil,
            let parentCommit = repository.commit(forSHA: firstParentSHA)
      else { break }

      if commit.parentSHAs.count > 1 {
        queue.append((parentCommit, commit))
        break
      }
      
      result.append(CommitEntry(commit: parentCommit))
      commit = parentCommit
    }
    
    let branchResult = BranchResult(entries: result, queue: queue)
    
    return branchResult
  }
  
  /// Adds new commits to the list.
  func process(startCommit: CommitType, afterCommit: CommitType? = nil)
  {
    guard let startSHA = startCommit.SHA where
          commitLookup[startSHA] == nil
    else { return }
    
    var results = [BranchResult]()
    var startCommit = startCommit
    
    repeat {
      var result = self.branchEntries(startCommit)
      
      defer { results.append(result) }
      if let nextSHA = result.entries.last?.commit.parentSHAs.first where
         commitLookup[nextSHA] == nil,
         let nextCommit = repository.commit(forSHA: nextSHA) {
        startCommit = nextCommit
      }
      else {
        break
      }
    } while true
    
    for result in results.reverse() {
      for (parent, after) in result.queue.reverse() {
        process(parent, afterCommit: after)
      }
      processBranchResult(result, after: afterCommit)
    }
  }
  
  func processBranchResult(result: BranchResult, after afterCommit: CommitType?)
  {
    for branchEntry in result.entries {
      if let sha = branchEntry.commit.SHA {
        commitLookup[sha] = branchEntry
      }
    }
    
    let afterIndex = afterCommit.flatMap(
        { commit in entries.indexOf({ $0.commit.SHA == commit.SHA }) })
    guard let lastEntry = result.entries.last
    else { return }
    let lastParentSHAs = lastEntry.commit.parentSHAs
    
    if let insertBeforeIndex = lastParentSHAs.flatMap(
           { sha in entries.indexOf({ $0.commit.SHA! == sha }) }).sort().first {
      if let afterIndex = afterIndex where
         afterIndex < insertBeforeIndex {
        entries.insertContentsOf(result.entries, at: afterIndex + 1)
      }
      else {
        entries.insertContentsOf(result.entries, at: insertBeforeIndex)
      }
    }
    else if
       let lastSecondarySHA = result.queue.last?.after.SHA,
       let lastSecondaryEntry = commitLookup[lastSecondarySHA],
       let lastSecondaryIndex = entries.indexOf(
          { return $0.commit.SHA == lastSecondaryEntry.commit.SHA }) {
      entries.insertContentsOf(result.entries, at: lastSecondaryIndex)
    }
    else if let afterIndex = afterIndex {
      entries.insertContentsOf(result.entries, at: afterIndex + 1)
    }
    else {
      entries.appendContentsOf(result.entries)
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
