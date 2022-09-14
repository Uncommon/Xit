import Foundation

struct HistoryLine: Sendable
{
  let childIndex, parentIndex: UInt?
  let colorIndex: UInt
}

final class CommitEntry: CustomStringConvertible
{
  let commit: any Commit
  fileprivate(set) var lines = [HistoryLine]()
  var dotOffset: UInt?
  var dotColorIndex: UInt?
  
  public var description: String
  { commit.description }
  
  init(commit: any Commit)
  {
    self.commit = commit
  }
}

func == (left: CommitEntry, right: CommitEntry) -> Bool
{
  return left.commit.id == right.commit.id
}


/// A connection line between commits in the history list.
struct CommitConnection<ID: OID>: Equatable, Sendable
{
  let parentOID, childOID: ID
  let colorIndex: UInt
}

func == <ID>(left: CommitConnection<ID>, right: CommitConnection<ID>) -> Bool
{
  return left.parentOID == right.parentOID &&
         left.childOID == right.childOID &&
         (left.colorIndex == right.colorIndex)
}


extension String
{
  func firstSix() -> String
  {
    return prefix(6).description
  }
}


typealias GitCommitHistory = CommitHistory<GitOID>

/// Maintains the history list, allowing for dynamic adding and removing.
final class CommitHistory<ID: OID & Hashable>
{
  typealias Entry = CommitEntry
  typealias Connection = CommitConnection<ID>
  typealias Repository = CommitStorage<ID>

  weak var repository: (any Repository)!
  
  var commitLookup = [ID: Entry]()
  var entries = [Entry]()
  private var abortFlag = false
  private var abortMutex = Mutex()
  public var syncMutex = Mutex()
  
  // start, end
  var postProgress: ((Int, Int) -> Void)?
  
  /// Manually appends a commit.
  func appendCommit(_ commit: any Commit)
  {
    entries.append(Entry(commit: commit))
  }

  func withSync<T>(_ callback: () throws -> T) rethrows -> T
  {
    try syncMutex.withLock(callback)
  }
  
  /// Clears the history list.
  public func reset()
  {
    abort()
    withSync {
      commitLookup.removeAll()
      entries.removeAll()
      batchStart = 0
      batchTargetRow = 0
      processingConnections = [Connection]()
    }
    resetAbort()
  }
  
  /// Signals that processing should be stopped.
  public func abort()
  {
    abortMutex.withLock {
      abortFlag = true
    }
  }
  
  public func resetAbort()
  {
    abortMutex.withLock {
      abortFlag = false
    }
  }
  
  func checkAbort() -> Bool
  {
    return abortMutex.withLock { abortFlag }
  }
  
  var batchSize = 500
  var batchStart = 0
  var batchTargetRow = 0
  var processingConnections = [Connection]()
  
  /// Processes the next batch of connections in the list. Should not be
  /// called on the main thread.
  func processNextConnectionBatch()
  {
    let batchSize = min(self.batchSize, entries.count - batchStart)
    let (connections, newConnections) =
          generateConnections(batchStart: batchStart,
                              batchSize: batchSize,
                              starting: processingConnections)
    
    Signpost.intervalStart(.generateLines(batchStart))
    DispatchQueue.concurrentPerform(iterations: batchSize) {
      (index) in
      guard !checkAbort() && (index + batchStart < entries.count)
      else { return }
      
      let entry = withSync { entries[index + batchStart] }
      
      generateLines(entry: entry, connections: connections[index])
    }
    postProgress?(batchStart, batchStart + batchSize)
    Signpost.intervalEnd(.generateLines(batchStart))
    withSync {
      processingConnections = newConnections
      batchStart += batchSize
    }
  }
  
  public func processFirstBatch()
  {
    batchStart = 0
    processBatches(throughRow: batchSize-1)
  }
  
  /// Starts processing rows until the given row is processed. If processing
  /// is already happening, the target is set to at least the given row.
  func processBatches(throughRow row: Int, queue: TaskQueue? = nil)
  {
    var startProcessing = false
    
    withSync {
      guard row > batchTargetRow
      else { return }
      
      startProcessing = batchTargetRow == 0
      batchTargetRow = row
    }

    if startProcessing {
      DispatchQueue.global(qos: .utility).async {
        if let queue = queue {
          queue.executeTask {
            self.processBatch()
          }
        }
        else {
          self.processBatch()
        }
      }
    }
  }
  
  private func processBatch()
  {
    while self.batchStart < min(self.withSync { self.batchTargetRow },
                                self.entries.count) {
      self.processNextConnectionBatch()
    }
    self.withSync { self.batchTargetRow = 0 }
  }
  
  /// Performs one batch of connection generation.
  /// - returns: The connections for the processed commits, and the starting
  /// connections for the next batch.
  func generateConnections(batchStart: Int, batchSize: Int,
                           starting: [Connection])
    -> ([[Connection]], [Connection])
  {
    Signpost.intervalStart(.generateConnections(batchStart), object: self)
    defer {
      Signpost.intervalEnd(.generateConnections(batchStart), object: self)
    }
    
    var result = [[Connection]]()
    var connections: [Connection] = starting
    var nextColorIndex: UInt = 0
    
    result.reserveCapacity(batchSize)
    for entry in entries[batchStart..<batchStart+batchSize] {
      let commitOID = entry.commit.id as! ID
      let incomingIndex = connections.firstIndex { $0.parentOID == commitOID }
      let incomingColor = incomingIndex.flatMap { connections[$0].colorIndex }
      
      if let firstParentOID = entry.commit.parentOIDs.first {
        let newConnection = Connection(parentOID: firstParentOID as! ID,
                                       childOID: commitOID,
                                       colorIndex: incomingColor ??
                                                   nextColorIndex++)
        let insertIndex = incomingIndex.flatMap { $0 + 1 } ??
                          connections.endIndex
        
        connections.insert(newConnection, at: insertIndex)
      }
      
      // Add new connections for the commit's parents
      for parentOID in entry.commit.parentOIDs.dropFirst() {
        connections.append(Connection(parentOID: parentOID as! ID,
                                      childOID: commitOID,
                                      colorIndex: nextColorIndex++))
      }
      
      result.append(connections)
      connections = connections.filter { $0.parentOID != commitOID }
    }
    
    return (result, connections)
  }
  
  private func parentIndex(_ parentOutlets: NSOrderedSet,
                           of id: ID) -> UInt?
  {
    let result = parentOutlets.index(of: id)
    
    return result == NSNotFound ? nil : UInt(result)
  }
  
  func generateLines(entry: CommitEntry,
                     connections: [CommitConnection<ID>])
  {
    var nextChildIndex: UInt = 0
    let parentOutlets = connections.compactMap {
        ($0.parentOID.equals(entry.commit.id)) ? nil : $0.parentOID }.unique()
    var parentLines: [ID: (childIndex: UInt,
                           colorIndex: UInt)] = [:]
    var generatedLines: [HistoryLine] = []
    
    for connection in connections {
      let commitIsParent = connection.parentOID.equals(entry.commit.id)
      let commitIsChild = connection.childOID.equals(entry.commit.id)
      let parentIndexInt = commitIsParent
              ? nil : parentOutlets.firstIndex(of: connection.parentOID)
      let parentIndex = parentIndexInt.map { UInt($0) }
      var childIndex: UInt? = commitIsChild
              ? nil : nextChildIndex
      var colorIndex = connection.colorIndex
      
      if (entry.dotOffset == nil) && (commitIsParent || commitIsChild) {
        withSync {
          entry.dotOffset = nextChildIndex
          entry.dotColorIndex = colorIndex
        }
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
      generatedLines.append(HistoryLine(childIndex: childIndex,
                                        parentIndex: parentIndex,
                                        colorIndex: colorIndex))
    }
    withSync {
      entry.lines.append(contentsOf: generatedLines)
    }
  }
}


/// The result of processing a segment of a branch.
struct BranchResult
{
  /// The commit entries collected for this segment.
  let entries: [CommitEntry]
  /// Other branches queued for processing.
  let queue: [(commit: any Commit, after: any Commit)]
}

extension BranchResult: CustomStringConvertible
{
  var description: String
  {
    guard let first = entries.first?.commit.id.sha.firstSix(),
          let last = entries.last?.commit.id.sha.firstSix()
    else { return "empty" }
    
    return "\(first)..\(last)"
  }
}


/// Functions for dynamically modifying the history list
/// (not currently used in the application)
extension CommitHistory
{
  /// Adds new commits to the list.
  public func process(_ startCommit: any Commit, afterCommit: (any Commit)? = nil)
  {
    let startOID = startCommit.id as! ID
    guard commitLookup[startOID] == nil
    else { return }
    
    var results = [BranchResult]()
    var startCommit = startCommit
    
    repeat {
      let result = branchEntries(startCommit: startCommit)
      
      defer { results.append(result) }
      if let nextOID = result.entries.last?.commit.parentOIDs.first as? ID,
         commitLookup[nextOID] == nil,
         let nextCommit = repository.anyCommit(forOID: nextOID) {
        startCommit = nextCommit
      }
      else {
        break
      }
    } while true
    
    for result in results.reversed() {
      if checkAbort() {
        break
      }
      for (parent, after) in result.queue.reversed() {
        process(parent, afterCommit: after)
      }
      processBranchResult(result, after: afterCommit)
    }
  }
  
  private func processBranchResult(_ result: BranchResult,
                                   after afterCommit: (any Commit)?)
  {
    for branchEntry in result.entries {
      commitLookup[branchEntry.commit.id as! ID] = branchEntry
    }
    
    let afterIndex = afterCommit.flatMap
        { commit in entries.firstIndex { $0.commit.id.equals(commit.id) } }
    guard let lastEntry = result.entries.last
    else { return }
    let lastParentOIDs = lastEntry.commit.parentOIDs
    
    if let insertBeforeIndex = lastParentOIDs.compactMap(
           { oid in entries.firstIndex(where: { $0.commit.id.equals(oid) }) })
           .sorted().first {
      #if DEBUGLOG
      print(" ** \(insertBeforeIndex) before \(entries[insertBeforeIndex].commit)")
      #endif
      if let afterIndex = afterIndex,
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
    else if let lastSecondaryOID = result.queue.last?.after.id as? ID,
            let lastSecondaryEntry = commitLookup[lastSecondaryOID],
            let lastSecondaryIndex = entries.firstIndex(where:
                { $0.commit.id.equals(lastSecondaryEntry.commit.id) }) {
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
  
  /// Creates a list of commits for the branch starting at the given commit, and
  /// also a list of secondary parents that may start other branches. A branch
  /// segment ends when a commit has more than one parent, or its parent is
  /// already registered.
  private func branchEntries(startCommit: any Commit) -> BranchResult
  {
    var commit = startCommit
    var result = [Entry(commit: startCommit)]
    var queue = [(commit: any Commit, after: any Commit)]()
    
    while let firstParentOID = commit.parentOIDs.first as? ID {
      for parentOID in commit.parentOIDs.dropFirst() {
        if let parentCommit = repository.anyCommit(forOID: parentOID as! ID) {
          queue.append((parentCommit, commit))
        }
      }
      
      guard commitLookup[firstParentOID] == nil,
            let parentCommit = repository.anyCommit(forOID: firstParentOID)
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
    let before = entries.last?.commit.parentOIDs.map { $0.SHA.firstSix() }
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
}
