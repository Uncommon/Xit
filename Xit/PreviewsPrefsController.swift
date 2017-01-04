import Cocoa

class PreviewsPrefsController: NSViewController
{
  @IBOutlet weak var whitespacePopup: NSPopUpButton!
  @IBOutlet weak var tabPopup: NSPopUpButton!

  struct PreferenceKeys
  {
    static let diffWhitespace = "diffWhitespace"
    static let tabWidth = "tabWidth"
  }

  enum WhitespaceSetting: String
  {
    case showAll
    case ignoreEOL
    case ignoreAll
    
    static let allValues: [WhitespaceSetting] = [.showAll, .ignoreEOL, .ignoreAll]
  }
  
  static let tabValues = [2, 4, 6, 8]

  override func viewDidLoad()
  {
    super.viewDidLoad()
    
    let defaults = UserDefaults.standard
    
    let defaultWhitespace = WhitespaceSetting.showAll
    let whitespaceString = defaults.string(forKey: PreferenceKeys.diffWhitespace)
                           ?? defaultWhitespace.rawValue
    let whitespaceValue = WhitespaceSetting.init(rawValue: whitespaceString)
                          ?? defaultWhitespace
    
    whitespacePopup.selectItem(at:
        WhitespaceSetting.allValues.index(of: whitespaceValue)!)
    
    let defaultTabWidth = 4
    var tabSetting = defaults.integer(forKey: PreferenceKeys.tabWidth)
    
    if tabSetting == 0 {
      tabSetting = defaultTabWidth
    }
    
    let tabIndex = PreviewsPrefsController.tabValues.index(of: tabSetting)
                ?? PreviewsPrefsController.tabValues.index(of: defaultTabWidth)!
    
    tabPopup.selectItem(at: tabIndex)
  }
}

extension PreviewsPrefsController: PreferencesSaver
{
  func savePreferences()
  {
    let defaults = UserDefaults.standard
    let whitespaceIndex = whitespacePopup.indexOfSelectedItem
    let tabIndex = tabPopup.indexOfSelectedItem
    
    defaults.set(WhitespaceSetting.allValues[whitespaceIndex].rawValue,
                 forKey: PreferenceKeys.diffWhitespace)
    defaults.set(PreviewsPrefsController.tabValues[tabIndex],
                 forKey: PreferenceKeys.tabWidth)
  }
}
