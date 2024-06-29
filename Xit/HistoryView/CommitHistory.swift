import Foundation

struct HistoryLine: Sendable
{
  let childIndex, parentIndex: UInt?
  let colorIndex: UInt
}

final class CommitEntry<C: Commit>: CustomStringConvertible
{
  let commit: C
  fileprivate(set) var lines = [HistoryLine]()
  var dotOffset: UInt?
  var dotColorIndex: UInt?
  
  public var description: String
  { commit.description }
  
  init(commit: C)
  {
    self.commit = commit
  }
}

extension CommitEntry: Equatable
{
  static func == (left: CommitEntry<C>, right: CommitEntry<C>) -> Bool
  {
    left.commit.id == right.commit.id
  }
}


/// A connection line between commits in the history list.
struct CommitConnection: Equatable, Sendable
{
  let parentOID, childOID: GitOID
  let colorIndex: UInt
}

func == (left: CommitConnection, right: CommitConnection) -> Bool
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


typealias GitCommitHistory = CommitHistory<GitCommit>

/// Maintains the history list, allowing for dynamic adding and removing.
final class CommitHistory<C: Commit>
{
  typealias Entry = CommitEntry<C>
  typealias Connection = CommitConnection
  typealias Repository = CommitStorage

  weak var repository: (any Repository)!
  
  var commitLookup = [GitOID: Entry]()
  var entries = [Entry]()
  private var abortFlag = false
  private var abortMutex = NSRecursiveLock()
  public var syncMutex = NSRecursiveLock()
  
  /// Progress reporting callback. Parameters are start and end. Will be
  /// called on the main thread.
  var postProgress: (@MainActor (Int, Int) -> Void)?

  /// Manually appends a commit.
  func appendCommit(_ commit: C)
  {
    entries.append(Entry(commit: commit))
  }

  func appendCommits(_ sequence: some Sequence<C>)
  {
    entries.append(contentsOf: sequence.map { Entry(commit: $0) })
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
    let currentBatchStart = batchStart
    let batchSize = min(self.batchSize, entries.count - currentBatchStart)
    let (connections, newConnections) =
          generateConnections(batchStart: currentBatchStart,
                              batchSize: batchSize,
                              starting: processingConnections)
    
    Signpost.intervalStart(.generateLines(batchStart))
    DispatchQueue.concurrentPerform(iterations: batchSize) {
      (index) in
      guard !checkAbort() && (index + currentBatchStart < entries.count)
      else { return }
      
      let entry = withSync { entries[index + currentBatchStart] }

      generateLines(entry: entry, connections: connections[index])
    }

    reportProgress(start: batchStart, end: batchStart + batchSize)
    Signpost.intervalEnd(.generateLines(batchStart))
    withSync {
      processingConnections = newConnections
      batchStart += batchSize
    }
  }

  func reportProgress(start: Int, end: Int)
  {
    if let postProgress = self.postProgress {
      DispatchQueue.main.async {
        postProgress(start, end)
      }
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
    Signpost.interval(.processBatches) {
      while self.batchStart < min(self.withSync { self.batchTargetRow },
                                  self.entries.count) {
        self.processNextConnectionBatch()
      }
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
      let commitOID = entry.commit.id
      let incomingIndex = connections.firstIndex {
        $0.parentOID == commitOID
      }
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
      connections = connections.filter {
        $0.parentOID != commitOID
      }
    }
    
    return (result, connections)
  }
  
  private func parentIndex(_ parentOutlets: NSOrderedSet,
                           of id: GitOID) -> UInt?
  {
    let result = parentOutlets.index(of: id)
    
    return result == NSNotFound ? nil : UInt(result)
  }
  
  func generateLines(entry: Entry,
                     connections: [CommitConnection])
  {
    // Seems like this cast shouldn't be necessary
    let entryID = entry.commit.id
    var nextChildIndex: UInt = 0
    let parentOutlets = connections.compactMap {
        ($0.parentOID == entryID) ? nil : $0.parentOID }.unique()
    var parentLines: [GitOID: (childIndex: UInt,
                               colorIndex: UInt)] = [:]
    var generatedLines: [HistoryLine] = []

    for connection in connections {
      let commitIsParent = connection.parentOID == entryID
      let commitIsChild = connection.childOID == entryID
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
struct BranchResult<C: Commit>
{
  /// The commit entries collected for this segment.
  let entries: [CommitEntry<C>]
  /// Other branches queued for processing.
  let queue: [(commit: C, after: C)]
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
  public func process(_ startCommit: C, afterCommit: C? = nil)
  {
    let startOID = startCommit.id
    guard commitLookup[startOID] == nil
    else { return }
    
    var results = [BranchResult<C>]()
    var startCommit = startCommit
    
    repeat {
      let result = branchEntries(startCommit: startCommit)
      
      defer { results.append(result) }
      if let nextOID = result.entries.last?.commit.parentOIDs.first,
         commitLookup[nextOID] == nil,
         let nextCommit = repository.anyCommit(forOID: nextOID) as? C {
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
  
  private func processBranchResult(_ result: BranchResult<C>,
                                   after afterCommit: C?)
  {
    for branchEntry in result.entries {
      commitLookup[branchEntry.commit.id] = branchEntry
    }
    
    let afterIndex = afterCommit.flatMap
        { commit in entries.firstIndex { $0.commit.id == commit.id } }
    guard let lastEntry = result.entries.last
    else { return }
    let lastParentOIDs = lastEntry.commit.parentOIDs
    
    if let insertBeforeIndex = lastParentOIDs.compactMap(
           {
             let oid = $0
             return entries.firstIndex(where: { $0.commit.id == oid })
           })
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
    else if let lastSecondaryOID = result.queue.last?.after.id,
            let lastSecondaryEntry = commitLookup[lastSecondaryOID],
            let lastSecondaryIndex = entries.firstIndex(where:
                { $0.commit.id == lastSecondaryEntry.commit.id }) {
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
  private func branchEntries(startCommit: C) -> BranchResult<C>
  {
    var commit = startCommit
    var result = [Entry(commit: startCommit)]
    var queue = [(commit: C, after: C)]()
    
    while let firstParentOID = commit.parentOIDs.first {
      for parentOID in commit.parentOIDs.dropFirst() {
        if let parentCommit = repository.anyCommit(forOID: parentOID) as? C {
          queue.append((parentCommit, commit))
        }
      }
      
      guard commitLookup[firstParentOID] == nil,
            let parentCommit = repository.anyCommit(forOID: firstParentOID) as? C
      else { break }

      if commit.parentOIDs.count > 1 {
        queue.append((parentCommit, commit))
        break
      }
      
      result.append(CommitEntry<C>(commit: parentCommit))
      commit = parentCommit
    }
    
    let branchResult = BranchResult<C>(entries: result, queue: queue)
    
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
