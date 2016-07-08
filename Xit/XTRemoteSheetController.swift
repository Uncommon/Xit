import Cocoa

class XTRemoteSheetController: XTSheetController {
  
  var selectedAccount: Account?
  {
    get { return teamCityPopup.selectedItem?.representedObject as? Account }
    set
    {
      if let newAccount = newValue {
        for item in teamCityPopup.itemArray {
          guard let itemAccount = item.representedObject as? Account
          else { continue }
          
          if itemAccount == newAccount {
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
    name = ""
    fetchURL = nil
    pushURL = nil
    resetTeamCityPopup()
  }
  
  func resetTeamCityPopup()
  {
    let accounts = XTAccountsManager.manager.accounts(ofType: .TeamCity)
    
    teamCityPopup.removeAllItems()
    teamCityPopup.addItemWithTitle("None")
    for account in accounts {
      let item = NSMenuItem()
      guard let host = account.location.host
      else { continue }
      
      item.title = "\(account.user)@\(host)"
      item.representedObject = account
      teamCityPopup.menu?.addItem(item)
    }
    teamCityPopup.selectItemAtIndex(0)
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
