import Foundation

extension HistoryViewController
{
  func toggleSearchBar()
  {
    searchController.isHidden.toggle()
  }
  
  func search(for text: String,
              type: HistorySearchType,
              direction: SearchDirection)
  {
    let search = text.lowercased()
    let entries = tableController.history.entries
    
    // I tried doing this with for loops and ranges, but the compiler refused.
    switch direction {
      case .up:
        var index = historyTable.selectedRow - 1
        
        while index >= 0 {
          if match(entry: entries[index], index: index, text: search, type: type) {
            break
          }
          index -= 1
        }
      case .down:
        var index = historyTable.selectedRow + 1
      
        while index < historyTable.numberOfRows {
          if match(entry: entries[index], index: index, text: search, type: type) {
            break
          }
          index += 1
        }
    }
  }
  
  func match(entry: CommitEntry<GitCommit>, index: Int, text: String,
             type: HistorySearchType)
    -> Bool
  {
    let commit = entry.commit
    var found = false
  
    switch type {
      case .summary:
        found = commit.message?.lowercased().contains(text) ?? false
      case .author:
        found = commit.authorSig?.contains(text) ?? false
      case .committer:
        found = commit.committerSig?.contains(text) ?? false
      case .sha:
        found = commit.id.sha.lowercased().hasPrefix(text)
    }
    if found {
      historyTable.selectRowIndexes(IndexSet(integer: index),
                                    byExtendingSelection: false)
      historyTable.scrollRowToVisible(index)
    }
    return found
  }
}
