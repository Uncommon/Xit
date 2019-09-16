import Cocoa

@objc protocol SidebarBottomDelegate: AnyObject
{
  func updateFilter(string: String?)
  func newBranch()
  func newRemote()
  func newTag()
}

class SidebarBottomController: NSViewController
{
  @IBOutlet weak var addButton: NSPopUpButton!
  @IBOutlet weak var settingsButton: NSPopUpButton!
  @IBOutlet weak var searchField: NSSearchField!
  
  @IBOutlet weak var delegate: SidebarBottomDelegate?
}

extension SidebarBottomController: NSSearchFieldDelegate
{
  func searchFieldDidStartSearching(_ sender: NSSearchField)
  {
    delegate?.updateFilter(string: searchField.stringValue.nilIfEmpty)
  }
  
  func searchFieldDidEndSearching(_ sender: NSSearchField)
  {
    delegate?.updateFilter(string: searchField.stringValue.nilIfEmpty)
  }
}

extension SidebarBottomController
{
  @IBAction func newBranch(_ sender: Any)
  {
    delegate?.newBranch()
  }

  @IBAction func newRemote(_ sender: Any)
  {
    delegate?.newRemote()
  }
  
  @IBAction func newTag(_ sender: Any)
  {
    delegate?.newTag()
  }
  
  @IBAction func toggleHideOld(_ sender: Any)
  {
  }
}
