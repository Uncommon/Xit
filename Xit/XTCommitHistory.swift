import Foundation

struct HistoryLine
{
  let childIndex, parentIndex: UInt?
  let colorIndex: UInt
}

public class CommitEntry<C: CommitType>: CustomStringConvertible
{
  let commit: C
  var lines = [HistoryLine]()
  var dotOffset: UInt?
  var dotColorIndex: UInt?
  
  public var description: String
  { return commit.description }
  
  init(commit: C)
  {
    self.commit = commit
  }
}

public func == <C: CommitType>(left: CommitEntry<C>,
                               right: CommitEntry<C>) -> Bool
{
  return left.commit.oid == right.commit.oid
}


/// A connection line between commits in the history list.
struct CommitConnection<ID: OID>: Equatable {
  let parentOID, childOID: ID
  let colorIndex: UInt
}

func == <ID: OID>(left: CommitConnection<ID>, right: CommitConnection<ID>) -> Bool
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


/// The result of processing a segment of a branch.
struct BranchResult<C: CommitType>: CustomStringConvertible
{
  /// The commit entries collected for this segment.
  var entries: [CommitEntry<C>]
  /// Other branches queued for processing.
  var queue: [(commit: C, after: C)]
  
  var description: String
  {
    guard let first = entries.first?.commit.sha?.firstSix(),
      let last = entries.last?.commit.sha?.firstSix()
      else { return "empty" }
    return "\(first)..\(last)"
  }
}

public typealias GitCommitHistory = XTCommitHistory<XTRepository>

/// Maintains the history list, allowing for dynamic adding and removing.
public class XTCommitHistory<Repo: RepositoryType>: NSObject
{
  typealias C = Repo.C
  typealias ID = Repo.C.ID
  typealias Entry = CommitEntry<C>
  typealias Connection = CommitConnection<ID>
  typealias Result = BranchResult<C>

  var repository: Repo!
  
  var commitLookup = [ID: Entry]()
  var entries = [Entry]()
  
  var postProgress: ((Int, Int) -> Void)?
  
  /// Manually appends a commit.
  func appendCommit(_ commit: C)
  {
    entries.append(Entry(commit: commit))
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
  func branchEntries(startCommit: C) -> Result
  {
    var commit: C = startCommit
    var result = [Entry(commit: startCommit)]
    var queue = [(commit: C, after: C)]()
    
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
    
    let branchResult = Result(entries: result, queue: queue)
    
#if DEBUGLOG
    let before = entries.last?.commit.parentOIDs.map({ $0.SHA.firstSix() })
                 .joinWithSeparator(" ")
    
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
  func process(_ startCommit: C, afterCommit: C? = nil)
  {
    let startOID = startCommit.oid
    guard commitLookup[startOID] == nil
    else { return }
    
    var results = [Result]()
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
  
  func processBranchResult(_ result: Result, after afterCommit: C?)
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
           { oid in entries.index(where: { $0.commit.oid == oid }) })
           .sorted().first {
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
        print(" *** \(result) before \(entries[insertBeforeIndex].commit) " +
              "(after \(afterCommit?.description ?? "-"))")
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
    let connections = generateConnections()
    
    DispatchQueue.concurrentPerform(iterations: entries.count) {
      (index) in
      postProgress?(index, 2)
      generateLines(entry: entries[index], connections: connections[index])
    }
  }
  
  func generateConnections() -> [[Connection]]
  {
    var result = [[Connection]]()
    var connections = [Connection]()
    var nextColorIndex: UInt = 0
    
    result.reserveCapacity(entries.count)
    for (index, entry) in entries.enumerated() {
      let commitOID = entry.commit.oid
      let incomingIndex = connections.index(where: { $0.parentOID == commitOID })
      let incomingColor = incomingIndex.flatMap { connections[$0].colorIndex }
      
      if let firstParentOID = entry.commit.parentOIDs.first {
        let newConnection = Connection(parentOID: firstParentOID,
                                       childOID: commitOID,
                                       colorIndex: incomingColor ??
                                                   nextColorIndex++)
        let insertIndex = incomingIndex.flatMap { $0 + 1 } ??
                          connections.endIndex
        
        connections.insert(newConnection, at: insertIndex)
      }
      
      // Add new connections for the commit's parents
      for parentOID in entry.commit.parentOIDs.dropFirst() {
        connections.append(Connection(parentOID: parentOID,
                                      childOID: commitOID,
                                      colorIndex: nextColorIndex++))
      }
      
      result.append(connections)
      connections = connections.filter { $0.parentOID != commitOID }
      
      postProgress?(index, 1)
    }
    
#if DEBUGLOG
    if !connections.isEmpty {
      print("Unterminated parent lines:")
      connections.forEach({ print($0.childOID.SHA.firstSix()) })
    }
#endif
    return result
  }
  
  func generateLines(entry: CommitEntry<C>,
                     connections: [CommitConnection<C.ID>])
  {
    var nextChildIndex: UInt = 0
    let parentOutlets = NSOrderedSet(array: connections.flatMap {
            ($0.parentOID == entry.commit.oid) ? nil : $0.parentOID })
    var parentLines: [C.ID: (childIndex: UInt,
                             colorIndex: UInt)] = [:]
    
    for connection in connections {
      let commitIsParent = connection.parentOID == entry.commit.oid
      let commitIsChild = connection.childOID == entry.commit.oid
      let parentIndex: UInt? = commitIsParent
              ? nil : UInt(parentOutlets.index(of: connection.parentOID))
      var childIndex: UInt? = commitIsChild
              ? nil : nextChildIndex
      var colorIndex = connection.colorIndex
      
      if (entry.dotOffset == nil) && (commitIsParent || commitIsChild) {
        entry.dotOffset = nextChildIndex
        entry.dotColorIndex = colorIndex
      }
      if let parentLine = parentLines[connection.parentOID] {
        if !commitIsChild {
          childIndex = parentLine.childIndex
          colorIndex = parentLine.colorIndex
        }
        else if !commitIsParent {
          nextChildIndex += 1
        }
      }
      else {
        if !commitIsChild {
          parentLines[connection.parentOID] = (
              childIndex: nextChildIndex,
              colorIndex: colorIndex)
        }
        if !commitIsParent {
          nextChildIndex += 1
        }
      }
      entry.lines.append(HistoryLine(childIndex: childIndex,
                                     parentIndex: parentIndex,
                                     colorIndex: colorIndex))
    }
  }
}
