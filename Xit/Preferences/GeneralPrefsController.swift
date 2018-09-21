import Foundation

class GeneralPrefsConroller: NSViewController
{
  @IBOutlet weak var collapsHistoryCheck: NSButton!
  @IBOutlet weak var deemphasizeCheck: NSButton!
  
  override func viewDidLoad()
  {
    super.viewDidLoad()
    
    collapsHistoryCheck.boolValue = UserDefaults.standard.collapseHistory
    deemphasizeCheck.boolValue = UserDefaults.standard.deemphasizeMerges
  }
  
  @IBAction func collapseHistoryClicked(_ sender: Any)
  {
    UserDefaults.standard.collapseHistory = collapsHistoryCheck.boolValue
  }
  
  @IBAction func deemphasizeClicked(_ sender: Any)
  {
    UserDefaults.standard.deemphasizeMerges = deemphasizeCheck.boolValue
  }
}
