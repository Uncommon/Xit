import Cocoa

class XTGitPrefsController: NSViewController, PreferencesSaver {
  
  @IBOutlet weak var userNameField: NSTextField!
  @IBOutlet weak var userEmailField: NSTextField!
  @IBOutlet weak var fetchTagsCheckbox: NSButton!
  @IBOutlet weak var fetchPruneCheckbox: NSButton!
  
  let config = GTConfiguration.defaultConfiguration()
  
  struct PrefKey {
    static let FetchTags = "FetchTags"
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    guard let config = config
    else {
      let allControls = [userNameField,
                         userEmailField,
                         fetchTagsCheckbox,
                         fetchPruneCheckbox]
      
      allControls.forEach { $0.enabled = false }
      return
    }
    
    userNameField.stringValue = config.stringForKey("user.name") ?? ""
    userEmailField.stringValue = config.stringForKey("user.email") ?? ""
    
    fetchPruneCheckbox.boolValue = config.boolForKey("fetch.prune")
    fetchTagsCheckbox.boolValue = NSUserDefaults.standardUserDefaults()
        .boolForKey(PrefKey.FetchTags)
    
    NSNotificationCenter.defaultCenter().addObserverForName(
        NSWindowDidResignKeyNotification,
        object: self.view.window,
        queue: nil) { (_) in
      self.savePreferences()
    }
  }
  
  func savePreferences()
  {
    config?.setString(userNameField.stringValue, forKey: "user.name")
    config?.setString(userEmailField.stringValue, forKey: "user.email")
    
    config?.setBool(fetchPruneCheckbox.boolValue, forKey: "fetch.prune")
    NSUserDefaults.standardUserDefaults().setBool(fetchTagsCheckbox.boolValue,
                                                  forKey: PrefKey.FetchTags)
  }
}
