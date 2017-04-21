import Cocoa

extension NSNotification.Name
{
  static let XTFontChanged = NSNotification.Name(rawValue:"XTFontChanged")
}

class PreviewsPrefsController: NSViewController
{
  @IBOutlet weak var whitespacePopup: NSPopUpButton!
  @IBOutlet weak var tabPopup: NSPopUpButton!
  @IBOutlet weak var fontField: NSTextField!
  
  var textFont: NSFont?
  {
    didSet
    {
      guard textFont != oldValue
      else { return }
      
      if let name = textFont?.displayName,
         let size = textFont?.pointSize {
        fontField.stringValue = "\(name) \(Int(size))"
      }
      else {
        fontField.stringValue = ""
      }
      saveFont()
      NotificationCenter.default.post(name: NSNotification.Name.XTFontChanged,
                                      object: nil)
    }
  }

  struct PreferenceKeys
  {
    static let diffWhitespace = "diffWhitespace"
    static let tabWidth = "tabWidth"
    static let fontName = "fontName"
    static let fontSize = "fontSize"
  }

  enum WhitespaceSetting: String
  {
    case showAll
    case ignoreEOL
    case ignoreAll
    
    static let allValues: [WhitespaceSetting] = [.showAll, .ignoreEOL, .ignoreAll]
  }
  
  static let tabValues = [2, 4, 6, 8]

  static func defaultFont() -> NSFont
  {
    let defaults = UserDefaults.standard
    let fontName = defaults.string(forKey: PreferenceKeys.fontName)
                   ?? "SF Mono"
    let storedSize = defaults.integer(forKey: PreferenceKeys.fontSize)
    let fontSize = CGFloat((storedSize == 0) ? 11 : storedSize)
    
    return NSFont(name: fontName, size: fontSize)
           ?? NSFont(name: "Monaco", size: fontSize)
           ?? NSFont.systemFont(ofSize: fontSize)
  }

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
    
    textFont = PreviewsPrefsController.defaultFont()
  }
  
  override func viewDidDisappear()
  {
    let manager = NSFontManager.shared()
    
    if manager.target === self {
      manager.target = nil
    }
  }
  
  @IBAction func showFontPanel(_ sender: Any)
  {
    guard let font = textFont
    else { return }
    
    let manager = NSFontManager.shared()
  
    manager.fontPanel(true)?.delegate = self
    manager.setSelectedFont(font, isMultiple: false)
    manager.orderFrontFontPanel(sender)
    manager.target = self
  }
  
  override func validModesForFontPanel(_ fontPanel: NSFontPanel) -> Int
  {
    return Int(NSFontPanelFaceModeMask |
               NSFontPanelSizeModeMask |
               NSFontPanelCollectionModeMask)
  }
  
  override func changeFont(_ sender: Any?)
  {
    guard let newFont = textFont.map({ NSFontManager.shared().convert($0) })
    else { return }
    
    textFont = newFont
  }
}

extension PreviewsPrefsController: NSWindowDelegate
{
  // Just needs the protocol to set the font panel delegate.
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
    
    saveFont()
  }
  
  func saveFont()
  {
    if let font = textFont {
      let defaults = UserDefaults.standard
      
      defaults.set(font.displayName, forKey: PreferenceKeys.fontName)
      defaults.set(Int(font.pointSize), forKey: PreferenceKeys.fontSize)
    }
  }
}
