import Cocoa

class GitPrefsController: NSViewController
{
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
    
    guard let config = config
    else {
      let allControls = [userNameField,
                         userEmailField,
                         fetchTagsCheckbox,
                         fetchPruneCheckbox] as [NSControl]
      
      allControls.forEach { $0.isEnabled = false }
      return
    }
    
    userNameField.stringValue = config[Keys.userName] ?? ""
    userEmailField.stringValue = config[Keys.userEmail] ?? ""
    
    fetchPruneCheckbox.boolValue = config[Keys.fetchPrune] ?? false
    fetchTagsCheckbox.boolValue = UserDefaults.standard
        .bool(forKey: PrefKey.fetchTags)
  }
}

extension GitPrefsController: PreferencesSaver
{
  func savePreferences()
  {
    if let config = config {
      config[Keys.userName] = userNameField.stringValue
      config[Keys.userEmail] = userEmailField.stringValue
      config[Keys.fetchPrune] = fetchPruneCheckbox.boolValue
    }
    UserDefaults.standard.set(fetchTagsCheckbox.boolValue,
                              forKey: PrefKey.fetchTags)
  }
}
