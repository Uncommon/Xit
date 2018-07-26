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

  public func toggleScopeBar()
  {
    setScopeBarVisble(scopeBar.isHidden)
  }
  
  @IBAction
  func searchAction(_ sender: Any)
  {
    guard let category =
      SearchCategory(rawValue: searchTypePopup.indexOfSelectedItem)
      else { return }
    
    performSearch(text: searchField.stringValue, type: category)
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

  func performSearch(text: String, type: SearchCategory)
  {
    let search = text.lowercased()
    
    for (index, entry) in self.tableController.history.entries.enumerated() {
      let commit = entry.commit
      var found = false
      
      switch type {
        case .summary:
          found = commit.message?.lowercased().contains(search) ?? false
        case .author:
          found = (commit.authorEmail?.lowercased().contains(search) ?? false) ||
                  (commit.authorName?.lowercased().contains(search) ?? false)
        case .committer:
          found = (commit.committerEmail?.lowercased().contains(search) ?? false) ||
                  (commit.committerName?.lowercased().contains(search) ?? false)
        case .sha:
          found = commit.oid.sha.lowercased().hasPrefix(search.lowercased())
      }
      if found {
        historyTable.selectRowIndexes(IndexSet(integer: index),
                                      byExtendingSelection: false)
        return
      }
    }
  }
}

extension XTHistoryViewController: NSSearchFieldDelegate
{
  func searchFieldDidStartSearching(_ sender: NSSearchField)
  {
    searchAction(sender)
  }
  
  func searchFieldDidEndSearching(_ sender: NSSearchField)
  {
  }
}
