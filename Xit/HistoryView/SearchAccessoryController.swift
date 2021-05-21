import Cocoa
import SwiftUI

protocol HistorySearchDelegate: AnyObject
{
  func search(for text: String,
              type: SearchAccessoryController.SearchType,
              direction: SearchAccessoryController.SearchDirection)
}

class SearchAccessoryController: NSTitlebarAccessoryViewController
{
  enum SearchType: Int
  {
    case summary, author, committer, sha
  }

  enum SearchDirection
  {
    case up, down
  }

  @IBOutlet weak var searchTypePopup: NSPopUpButton!
  @IBOutlet weak var searchField: NSSearchField!
  @IBOutlet weak var searchButtons: NSSegmentedControl!
  
  weak var delegate: HistorySearchDelegate?

  override var layoutAttribute: NSLayoutConstraint.Attribute
  {
    get { .bottom }
    set {}
  }
  
  var searchType: SearchType
  {
    .init(rawValue: searchTypePopup.indexOfSelectedItem) ?? .summary
  }
  
  @IBAction func search(_ sender: Any)
  {
    search(.down)
  }
  
  @IBAction
  func searchSegment(_ sender: NSSegmentedControl)
  {
    search(sender.selectedSegment == 0 ? .up : .down)
  }

  @IBAction func close(_ sender: Any)
  {
    isHidden = true
  }
  
  func search(_ direction: SearchDirection)
  {
    let text: String = searchField.stringValue
    guard !text.isEmpty
    else { return }
    
    delegate?.search(for: text, type: searchType, direction: direction)
  }
}

extension SearchAccessoryController: NSSearchFieldDelegate
{
  func searchFieldDidStartSearching(_ sender: NSSearchField)
  {
    search(.down)
  }

  func controlTextDidChange(_ obj: Notification)
  {
    searchButtons.isEnabled = !searchField.stringValue.isEmpty
  }
}
