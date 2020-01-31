import Foundation

class GeneralPrefsConroller: NSViewController
{
  @IBOutlet weak var collapsHistoryCheck: NSButton!
  @IBOutlet weak var deemphasizeCheck: NSButton!
  @IBOutlet weak var resetAmendCheck: NSButton!
  @IBOutlet weak var tabStatusButton: NSButton!
  
  @IBOutlet weak var userNameField: NSTextField!
  @IBOutlet weak var userEmailField: NSTextField!
  @IBOutlet weak var fetchTagsCheckbox: NSButton!
  @IBOutlet weak var fetchPruneCheckbox: NSButton!

  let config = GitConfig.default
  
  enum Keys
  {
    static let userName = "user.name"
    static let userEmail = "user.email"
    static let fetchPrune = "fetch.prune"
  }
  
  enum PrefKey
  {
    static let fetchTags = "FetchTags"
  }

  override func viewDidLoad()
  {
    super.viewDidLoad()
    
    let defaults = UserDefaults.standard
    
    collapsHistoryCheck.boolValue = defaults.collapseHistory
    deemphasizeCheck.boolValue = defaults.deemphasizeMerges
    resetAmendCheck.boolValue = defaults.resetAmend
    tabStatusButton.boolValue = defaults.statusInTabs

    if let config = self.config {
      userNameField.stringValue = config[Keys.userName] ?? ""
      userEmailField.stringValue = config[Keys.userEmail] ?? ""
      
      fetchPruneCheckbox.boolValue = config[Keys.fetchPrune] ?? false
      fetchTagsCheckbox.boolValue = UserDefaults.standard
          .bool(forKey: PrefKey.fetchTags)
    }
    else {
      let allControls: [NSControl] = [userNameField,
                                      userEmailField,
                                      fetchTagsCheckbox,
                                      fetchPruneCheckbox]
      
      for control in allControls {
        control.isEnabled = false
      }
    }
  }
  
  @IBAction
  func collapseHistoryClicked(_ sender: Any)
  {
    UserDefaults.standard.collapseHistory = collapsHistoryCheck.boolValue
  }
  
  @IBAction
  func deemphasizeClicked(_ sender: Any)
  {
    UserDefaults.standard.deemphasizeMerges = deemphasizeCheck.boolValue
  }
  
  @IBAction func resetAmendClicked(_ sender: Any)
  {
    UserDefaults.standard.resetAmend = resetAmendCheck.boolValue
  }
  
  @IBAction func tabStatusClicked(_ sender: NSButton)
  {
    UserDefaults.standard.statusInTabs = tabStatusButton.boolValue
  }
}

extension GeneralPrefsConroller: PreferencesSaver
{
  func savePreferences()
  {
    if let config = self.config {
      config[Keys.userName] = userNameField.stringValue
      config[Keys.userEmail] = userEmailField.stringValue
      config[Keys.fetchPrune] = fetchPruneCheckbox.boolValue
    }
    UserDefaults.standard.set(fetchTagsCheckbox.boolValue,
                              forKey: PrefKey.fetchTags)
  }
}
