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
  
  func updateSearh()
  {
    delegate?.updateFilter(string: searchField.stringValue.nilIfEmpty)
  }
}

extension SidebarBottomController: NSSearchFieldDelegate
{
  func searchFieldDidStartSearching(_ sender: NSSearchField)
  {
    updateSearh()
  }
  
  func searchFieldDidEndSearching(_ sender: NSSearchField)
  {
    updateSearh()
  }
  
  func controlTextDidChange(_ obj: Notification)
  {
    updateSearh()
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
