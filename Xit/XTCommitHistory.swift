import Foundation


// Inherits from NSObject just to make it accessible to ObjC
public class CommitEntry: NSObject
{
  struct Line
  {
    let childIndex, parentIndex: UInt?
    let colorIndex: UInt
  }

  let commit: CommitType
  var connections = [CommitConnection]()
  {
    didSet
    {
      generateLines()
    }
  }
  var lines = [Line]()
  var dotOffset: UInt? = nil
  var dotColorIndex: UInt? = nil
  
  public override var description: String
  { return commit.description }
  
  init(commit: CommitType)
  {
    self.commit = commit
  }
  
  func generateLines()
  {
    var topOffset: UInt = 0
    var bottomOffset: UInt = 0
    let parentOutlets = NSOrderedSet(array: connections.map { $0.parentOID })
    var parentLines = [GTOID: (parentIndex: UInt,
                               childIndex: UInt,
                               colorIndex: UInt)]()

    for connection in connections {
      if parentLines[connection.parentOID] == nil {
        parentLines[connection.parentOID] = (bottomOffset,
                                             topOffset,
                                             connection.colorIndex)
        if connection.parentOID != commit.oid {
          bottomOffset += 1
        }
        if connection.childOID != commit.oid {
          topOffset += 1
        }
      }
    }
    topOffset = 0
    bottomOffset = 0
    
    
    for connection in connections {
      let parentIndex = parentOutlets.index(of: connection.parentOID)
      var connectionColor = connection.colorIndex
      let previousLine = parentLines[connection.parentOID]
    
      if connection.parentOID == commit.oid {
        let (offset, _, lineColor) = previousLine
                ?? (topOffset, 0, connectionColor)
        
        connectionColor = lineColor
        if dotOffset == nil {
          dotOffset = topOffset
          dotColorIndex = connection.colorIndex
        }
        lines.append(Line(childIndex: offset,
                          parentIndex: nil,
                          colorIndex: connectionColor))
        topOffset += 1
      }
      else if connection.childOID == commit.oid {
        let (offset, _, _) = previousLine
                ?? (bottomOffset, 0, 0)
        
        if dotOffset == nil {
          dotOffset = topOffset
          dotColorIndex = connection.colorIndex
        }
        lines.append(Line(childIndex: nil,
                          parentIndex: offset,
                          colorIndex: connectionColor))
        if offset == bottomOffset {
          bottomOffset += 1
        }
      }
      else {
        var useTopOffset = topOffset
        var useBottomOffset = bottomOffset
        
        if let (parentOffset, childOffset, lineColor) = previousLine {
          useTopOffset = childOffset
          useBottomOffset = parentOffset
          connectionColor = lineColor
          if let dotOffset = dotOffset,
             useTopOffset == dotOffset {
            useTopOffset += 1
            topOffset += 1
          }
        }
        lines.append(Line(childIndex: useTopOffset,
                          parentIndex: useBottomOffset,
                          colorIndex: connectionColor))
        if useTopOffset == topOffset {
          topOffset += 1
        }
        if useBottomOffset == bottomOffset {
          bottomOffset += 1
        }
      }
    }
  }
}

public func == (left: CommitEntry, right: CommitEntry) -> Bool
{
  return left.commit.oid == right.commit.oid
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


extension String
{
  func firstSix() -> String
  {
    return utf8.prefix(6).description
  }
}


/// Maintains the history list, allowing for dynamic adding and removing.
public class XTCommitHistory: NSObject
{
  var repository: RepositoryType!
  
  var commitLookup = [GTOID: CommitEntry]()
  var entries = [CommitEntry]()
  
  /// The result of processing a segment of a branch.
  struct BranchResult: CustomStringConvertible {
    /// The commit entries collected for this segment.
    var entries: [CommitEntry]
    /// Other branches queued for processing.
    var queue: [(commit: CommitType, after: CommitType)]
    
    var description: String
    {
      guard let first = entries.first?.commit.sha?.firstSix(),
            let last = entries.last?.commit.sha?.firstSix()
      else { return "empty" }
      return "\(first)..\(last)"
    }
  }
  
  /// Manually appends a commit.
  func appendCommit(_ commit: CommitType)
  {
    entries.append(CommitEntry(commit: commit))
  }
  
  /// Clears the history list.
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
  func process(_ startCommit: CommitType, afterCommit: CommitType? = nil)
  {
    let startOID = startCommit.oid
    guard commitLookup[startOID] == nil
    else { return }
    
    var results = [BranchResult]()
    var startCommit = startCommit
    
    repeat {
      var result = self.branchEntries(startCommit: startCommit)
      
      defer { results.append(result) }
      if let nextOID = result.entries.last?.commit.parentOIDs.first ,
         commitLookup[nextOID] == nil,
         let nextCommit = repository.commit(forOID: nextOID) {
        startCommit = nextCommit
      }
      else {
        break
      }
    } while true
    
    for result in results.reversed() {
      for (parent, after) in result.queue.reversed() {
        process(parent, afterCommit: after)
      }
      processBranchResult(result, after: afterCommit)
    }
  }
  
  func processBranchResult(_ result: BranchResult, after afterCommit: CommitType?)
  {
    for branchEntry in result.entries {
      commitLookup[branchEntry.commit.oid] = branchEntry
    }
    
    let afterIndex = afterCommit.flatMap(
        { commit in entries.index(where: { $0.commit.oid == commit.oid }) })
    guard let lastEntry = result.entries.last
    else { return }
    let lastParentOIDs = lastEntry.commit.parentOIDs
    
    if let insertBeforeIndex = lastParentOIDs.flatMap(
           { oid in entries.index(where: { $0.commit.oid == oid }) }).sorted().first {
      #if DEBUGLOG
      print(" ** \(insertBeforeIndex) before \(entries[insertBeforeIndex].commit)")
      #endif
      if let afterIndex = afterIndex ,
         afterIndex < insertBeforeIndex {
        #if DEBUGLOG
        print(" *** \(result) after \(afterCommit?.description ?? "")")
        #endif
        entries.insert(contentsOf: result.entries, at: afterIndex + 1)
      }
      else {
        #if DEBUGLOG
        print(" *** \(result) before \(entries[insertBeforeIndex].commit) (after \(afterCommit?.description ?? "-"))")
        #endif
        entries.insert(contentsOf: result.entries, at: insertBeforeIndex)
      }
    }
    else if
       let lastSecondaryOID = result.queue.last?.after.oid,
       let lastSecondaryEntry = commitLookup[lastSecondaryOID],
       let lastSecondaryIndex = entries.index(
          where: { return $0.commit.oid == lastSecondaryEntry.commit.oid }) {
      #if DEBUGLOG
      print(" ** after secondary \(lastSecondaryOID.SHA!.firstSix())")
      #endif
      entries.insert(contentsOf: result.entries, at: lastSecondaryIndex)
    }
    else if let afterIndex = afterIndex {
      #if DEBUGLOG
      print(" ** \(result) after \(afterCommit?.description ?? "")")
      #endif
      entries.insert(contentsOf: result.entries, at: afterIndex + 1)
    }
    else {
      #if DEBUGLOG
      print(" ** appending \(result)")
      #endif
      entries.append(contentsOf: result.entries)
    }
  }
  
  
  /// Creates the connections to be drawn between commits.
  func connectCommits()
  {
    var connections = [CommitConnection]()
    var nextColorIndex: UInt = 0
    
    for entry in entries {
      let commitOID = entry.commit.oid
      let incomingIndex = connections.index(where: { $0.parentOID == commitOID })
      let incomingColor = incomingIndex.flatMap { connections[$0].colorIndex }
      
      if let firstParentOID = entry.commit.parentOIDs.first {
        let newConnection = CommitConnection(parentOID: firstParentOID,
                                             childOID: commitOID,
                                             colorIndex: incomingColor ??
                                                         nextColorIndex++)
        let insertIndex = incomingIndex.flatMap { $0 + 1 } ??
                          connections.endIndex
        
        connections.insert(newConnection, at: insertIndex)
      }
      
      // Add new connections for the commit's parents
      for parentOID in entry.commit.parentOIDs.dropFirst() {
        connections.append(CommitConnection(parentOID: parentOID,
                                            childOID: commitOID,
                                            colorIndex: nextColorIndex++))
      }
      
      entry.connections = connections
      connections = connections.filter { $0.parentOID != commitOID }
    }
#if DEBUGLOG
    if !connections.isEmpty {
      print("Unterminated parent lines:")
      connections.forEach({ print($0.childOID.SHA.firstSix()) })
    }
#endif
  }
}
