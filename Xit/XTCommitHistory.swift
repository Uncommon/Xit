import Foundation


// Inherits from NSObject just to make it accessible to ObjC
public class CommitEntry: NSObject {
  let commit: CommitType
  var connections = [CommitConnection]()
  var incoming: UInt = 0
  
  public override var description: String
  { return commit.description }
  
  init(commit: CommitType)
  {
    self.commit = commit
  }
}

public func == (left: CommitEntry, right: CommitEntry) -> Bool
{
  return left.commit.OID == right.commit.OID
}


/// A connection line between commits in the history list.
struct CommitConnection: Equatable {
  let parentOID, childOID: GTOID
  let colorIndex: UInt
}

func == (left: CommitConnection, right: CommitConnection) -> Bool
{
  return (left.parentOID == right.parentOID) &&
         (left.childOID == right.childOID) &&
         (left .colorIndex == right.colorIndex)
}


extension String {
  func firstSix() -> String
  {
    return utf8.prefix(6).description
  }
}


extension GTOID {
  override public var description: String
  { return SHA.firstSix() }
}


public class XTCommitHistory: NSObject {
  
  var repository: RepositoryType!
  
  var commitLookup = [GTOID: CommitEntry]()
  var entries = [CommitEntry]()
  
  let cache = IndexCache<GTOID>()
  
  /// The result of processing a segment of a branch.
  struct BranchResult: CustomStringConvertible {
    /// The commit entries collected for this segment.
    var entries: [CommitEntry]
    /// Other branches queued for processing.
    var queue: [(commit: CommitType, after: CommitType)]
    
    var description: String
    {
      guard let first = entries.first?.commit.SHA?.firstSix(),
            let last = entries.last?.commit.SHA?.firstSix()
      else { return "empty" }
      return "\(first)..\(last)"
    }
  }
  
  func reset()
  {
    commitLookup.removeAll()
    entries.removeAll()
    cache.reset()
  }
  
  func indexOf(oid: GTOID) -> Int?
  {
    if let index = cache.indexOf(oid) {
      assert(entries[index].commit.OID == oid)
      return index
    }
    
    for index in (cache.lastValidIndex+1)..<entries.count {
      cache.setIndex(index, forValue: entries[index].commit.OID)
      if entries[index].commit.OID == oid {
        return index
      }
    }
    
    return nil
  }
  
  func insertEntries(newEntries: [CommitEntry], at index: Int)
  {
    cache.invalidate(index: index)
    entries.insertContentsOf(newEntries, at: index)
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
    
    while let firstParentOID = commit.parentOIDs.first {
      for parentOID in commit.parentOIDs.dropFirst() {
        if let parentCommit = repository.commit(forOID: parentOID) {
          queue.append((parentCommit, commit))
        }
      }
      
      guard commitLookup[firstParentOID] == nil,
            let parentCommit = repository.commit(forOID: firstParentOID)
      else { break }

      if commit.parentOIDs.count > 1 {
        queue.append((parentCommit, commit))
        break
      }
      
      result.append(CommitEntry(commit: parentCommit))
      commit = parentCommit
    }
    
    let branchResult = BranchResult(entries: result, queue: queue)
    
#if DEBUGLOG
    let before = entries.last?.commit.parentOIDs.map({ $0.SHA.firstSix() }).joinWithSeparator(" ")
    
    print("\(branchResult) ‹ \(before ?? "-")", terminator: "")
    for (commit, after) in queue {
      print(" (\(commit.SHA!.firstSix()) › \(after.SHA!.firstSix()))",
            terminator: "")
    }
    print("")
#endif
    return branchResult
  }
  
  /// Adds new commits to the list.
  func process(startCommit: CommitType, afterCommit: CommitType? = nil)
  {
    let startOID = startCommit.OID
    guard commitLookup[startOID] == nil
    else { return }
    
    var results = [BranchResult]()
    var startCommit = startCommit
    
    repeat {
      var result = self.branchEntries(startCommit)
      
      defer { results.append(result) }
      if let nextOID = result.entries.last?.commit.parentOIDs.first where
         commitLookup[nextOID] == nil,
         let nextCommit = repository.commit(forOID: nextOID) {
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
      commitLookup[branchEntry.commit.OID] = branchEntry
    }
    
    let afterIndex = afterCommit.flatMap({ indexOf($0.OID) })
    guard let lastEntry = result.entries.last
    else { return }
    let lastParentOIDs = lastEntry.commit.parentOIDs
    
    if let insertBeforeIndex = lastParentOIDs.flatMap(
           { indexOf($0) }).sort().first {
      #if DEBUGLOG
      print(" ** \(insertBeforeIndex) before \(entries[insertBeforeIndex].commit)")
      #endif
      if let afterIndex = afterIndex where
         afterIndex < insertBeforeIndex {
        #if DEBUGLOG
        print(" *** \(result) after \(afterCommit?.description ?? "")")
        #endif
        insertEntries(result.entries, at: afterIndex + 1)
      }
      else {
        #if DEBUGLOG
        print(" *** \(result) before \(entries[insertBeforeIndex].commit) (after \(afterCommit?.description ?? "-"))")
        #endif
        insertEntries(result.entries, at: insertBeforeIndex)
      }
    }
    else if
       let lastSecondaryOID = result.queue.last?.after.OID,
       let lastSecondaryEntry = commitLookup[lastSecondaryOID],
       let lastSecondaryIndex = indexOf(lastSecondaryEntry.commit.OID) {
      #if DEBUGLOG
      print(" ** after secondary \(lastSecondaryOID.SHA!.firstSix())")
      #endif
      insertEntries(result.entries, at: lastSecondaryIndex)
    }
    else if let afterIndex = afterIndex {
      #if DEBUGLOG
      print(" ** \(result) after \(afterCommit?.description ?? "")")
      #endif
      insertEntries(result.entries, at: afterIndex + 1)
    }
    else {
      #if DEBUGLOG
      print(" ** appending \(result)")
      #endif
      entries.appendContentsOf(result.entries)
    }
  }
  
  
  /// Creates the connections to be drawn between commits.
  func connectCommits()
  {
    var connections = [CommitConnection]()
    var nextColorIndex: UInt = 0
    
    for entry in entries {
      let commitOID = entry.commit.OID
      let incomingIndex = connections.indexOf({ $0.parentOID == commitOID })
      let incomingColor: UInt? = (incomingIndex != nil)
          ? connections[incomingIndex!].colorIndex
          : nil
      
      if let firstParentOID = entry.commit.parentOIDs.first {
        let newConnection = CommitConnection(parentOID: firstParentOID,
                                             childOID: commitOID,
                                             colorIndex: incomingColor ??
                                                         nextColorIndex++)
        let insertIndex = (incomingIndex != nil)
            ? incomingIndex! + 1
            : connections.endIndex
        
        connections.insert(newConnection, atIndex: insertIndex)
      }
      
      // Add new connections for the commit's parents
      for parentOID in entry.commit.parentOIDs.dropFirst() {
        connections.append(CommitConnection(parentOID: parentOID,
                                            childOID: commitOID,
                                            colorIndex: nextColorIndex++))
      }
      
      entry.connections = connections
      connections = connections.filter({ $0.parentOID != commitOID })
    }
#if DEBUGLOG
    if !connections.isEmpty {
      print("Unterminated parent lines:")
      connections.forEach({ print($0.childOID.SHA.firstSix()) })
    }
#endif
  }
}
