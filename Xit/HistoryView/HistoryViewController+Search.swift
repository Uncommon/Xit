import Foundation

extension HistoryViewController: HistorySearchDelegate
{
  func toggleSearchBar()
  {
    searchController.isHidden.toggle()
  }
  
  func search(for text: String,
              type: SearchAccessoryController.SearchType,
              direction: SearchAccessoryController.SearchDirection)
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
  
  func match(entry: CommitEntry, index: Int, text: String,
             type: SearchAccessoryController.SearchType)
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
        found = commit.oid.sha.lowercased().hasPrefix(text)
    }
    if found {
      historyTable.selectRowIndexes(IndexSet(integer: index),
                                    byExtendingSelection: false)
      historyTable.scrollRowToVisible(index)
    }
    return found
  }
}
