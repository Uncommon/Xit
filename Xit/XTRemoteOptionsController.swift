import Cocoa

class XTRemoteOptionsController: XTSheetController {
  
  var remoteName: String = ""
  {
    didSet
    {
      guard let remote = try? GTRemote(name: remoteName,
                                       inRepository: repository!.gtRepo)
      else { return }
      
      fetchURL = NSURL(string: remote.URLString ?? "")
      pushURL = NSURL(string: remote.pushURLString ?? "")
    }
  }
  
  var selectedAccount: Account?
  {
    get { return teamCityPopup.selectedItem?.representedObject as? Account }
    set
    {
      if let newItem = newValue {
        for item in teamCityPopup.itemArray {
          if item.representedObject as? Account == newItem {
            teamCityPopup.selectItem(item)
            return
          }
        }
      }
      teamCityPopup.selectItemAtIndex(0)
    }
  }
  
  var repository: XTRepository? = nil
  
  @IBOutlet weak var nameField: NSTextField!
  @IBOutlet weak var fetchField: NSTextField!
  @IBOutlet weak var pushField: NSTextField!
  @IBOutlet weak var teamCityPopup: NSPopUpButton!
  
  var name: String
  {
    get { return nameField.stringValue }
    set { nameField.stringValue = newValue }
  }
  var fetchURL: NSURL?
  {
    get { return NSURL(string: fetchField.stringValue) }
    set { fetchField.stringValue = newValue?.absoluteString ?? "" }
  }
  var pushURL: NSURL?
    {
    get { return NSURL(string: pushField.stringValue) }
    set { pushField.stringValue = newValue?.absoluteString ?? "" }
  }
  
  override func resetFields()
  {
    resetTeamCityPopup()
  }
  
  func resetTeamCityPopup()
  {
    let accounts = XTAccountsManager.manager.accounts(ofType: .TeamCity)
    
    teamCityPopup.removeAllItems()
    teamCityPopup.addItemWithTitle("None")
    for account in accounts {
      let item = NSMenuItem()
      
      item.title = "\(account.user)@\(account.location.host)"
      item.representedObject = account
      teamCityPopup.menu?.addItem(item)
    }
  }
  
  @IBAction func teamCityChanged(sender: AnyObject)
  {
  }
  
  override func accept(sender: AnyObject)
  {
    // validate the fields
    
    super.accept(sender)
  }
}
