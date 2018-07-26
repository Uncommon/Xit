import Foundation

extension XTHistoryViewController
{
  enum Constants
  {
    static let shownScopeHeight: CGFloat = 30
  }
  
  enum SearchCategory: Int
  {
    case summary
    case author
    case committer
    case sha
  }

  func setUpScopeBar()
  {
    scopeBar.isHidden = true
    scopeHeightConstraint.constant = 0
  }
  
  public func toggleScopeBar()
  {
    setScopeBarVisble(scopeBar.isHidden)
  }
  
  @IBAction
  func searchAction(_ sender: Any)
  {
    search(reversed: false)
  }
  
  @IBAction
  func searchSegment(_ sender: NSSegmentedControl)
  {
    search(reversed: sender.selectedSegment == 0)
  }
  
  func setScopeBarVisble(_ visible: Bool)
  {
    NSAnimationContext.runAnimationGroup({
      (context) in
      context.duration = 0.25
      context.allowsImplicitAnimation = true
      scopeBar.isHidden = !visible
      scopeHeightConstraint.constant = visible ? Constants.shownScopeHeight : 0
      mainSplitView.layoutSubtreeIfNeeded()
    }, completionHandler: nil)
  }

  func search(reversed: Bool)
  {
    guard let category =
        SearchCategory(rawValue: searchTypePopup.indexOfSelectedItem)
    else { return }
    
    performSearch(text: searchField.stringValue, type: category,
                  reversed: reversed)
  }
  
  func performSearch(text: String, type: SearchCategory, reversed: Bool = false)
  {
    let search = text.lowercased()
    let entries = tableController.history.entries
    
    // I tried doing this with for loops and ranges, but the compiler refused.
    if reversed {
      var index = historyTable.selectedRow - 1
      
      while index >= 0 {
        if match(entry: entries[index], index: index, text: search, type: type) {
          break
        }
        index -= 1
      }
    }
    else {
      var index = historyTable.selectedRow + 1
      
      while index < historyTable.numberOfRows {
        if match(entry: entries[index], index: index, text: search, type: type) {
          break
        }
        index += 1
      }
    }
  }
  
  func match(entry: CommitEntry, index: Int, text: String, type: SearchCategory)
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

extension XTHistoryViewController: NSSearchFieldDelegate
{
  func searchFieldDidStartSearching(_ sender: NSSearchField)
  {
    search(reversed: false)
  }
  
  func searchFieldDidEndSearching(_ sender: NSSearchField)
  {
  }
  
  override func controlTextDidChange(_ obj: Notification)
  {
    searchButtons.isEnabled = !searchField.stringValue.isEmpty
  }
}
