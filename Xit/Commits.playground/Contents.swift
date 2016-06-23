import Cocoa

struct Commit {
  var sha: String
  var parents: [Commit]
}

class CommitEntry {
  let commit: Commit
  var children: [Commit] = [Commit]()
  
  init(commit: Commit)
  {
    self.commit = commit
  }
}

class CommitHistory {

  var commitLookup: [String: CommitEntry]
  var entries: [CommitEntry]
  
  init()
  {
    self.commitLookup = [String: CommitEntry]()
    self.entries = [CommitEntry]()
  }
  
  func add(commit: Commit, toParent parent: Commit?) -> Bool
  {
    guard commitLookup[commit.sha] == nil
    else { return false }
    
    
    let entry = CommitEntry(commit: commit)
    commitLookup[commit.sha] = entry
    entries.append(entry) // actually insert it after the previous parent's commnits
    return true;
  }

  func process(startCommit: Commit, parent: Commit?)
  {
    var parent = parent
    var commit = startCommit
    var parentStack = [(Commit, Commit)]()
    
    while add(commit, toParent: parent) && !commit.parents.isEmpty {
      if commit.parents.count > 1 {
        let parents = commit.parents[1..<commit.parents.count]
        
        parentStack.appendContentsOf(parents.map({ return ($0, commit) }))
      }
      parent = commit
      commit = commit.parents[0]
    }
    for (commit, parent) in parentStack { // need to reverse order?
      process(commit, parent: parent)
    }
  }

}
