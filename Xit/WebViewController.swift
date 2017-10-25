import Cocoa
import WebKit

protocol WebActionDelegateHost
{
  var webActionDelegate: Any { get }
}

class WebViewController: NSViewController
{
  @IBOutlet weak var webView: WebView!
  var savedTabWidth: UInt?
  var savedWrapping: Wrapping?
  var fontObserver: NSObjectProtocol?
  
  struct Default
  {
    static var tabWidth: UInt
    { return PreviewsPrefsController.Default.tabWidth() }
  }
  
  static let baseURL = Bundle.main.url(forResource: "html", withExtension: nil)
  
  static func htmlTemplate(_ name: String) -> String
  {
    guard let htmlURL = Bundle.main.url(forResource: name, withExtension: "html",
                                        subdirectory: "html")
    else { return "" }
    
    return (try? String(contentsOf: htmlURL)) ?? ""
  }
  
  static func escape(text: String) -> String
  {
    return CFXMLCreateStringByEscapingEntities(kCFAllocatorDefault,
                                               text as CFString,
                                               [:] as CFDictionary) as String
  }
  
  override func awakeFromNib()
  {
    fontObserver = NotificationCenter.default.addObserver(
        forName: NSNotification.Name.XTFontChanged, object: nil, queue: .main) {
      [weak self] (_) in
      self?.updateFont()
    }
  }
  
  func updateFont()
  {
    let font = PreviewsPrefsController.Default.font()
    
    webView?.preferences.standardFontFamily = font.familyName
    webView?.preferences.defaultFontSize = Int32(font.pointSize)
    webView?.preferences.defaultFixedFontSize = Int32(font.pointSize)
  }
  
  public func loadNotice(_ text: String)
  {
    let template = WebViewController.htmlTemplate("notice")
    let escapedText = WebViewController.escape(text: text)
    let html = String(format: template, escapedText)
    
    webView?.mainFrame.loadHTMLString(html, baseURL: WebViewController.baseURL)
  }
  
  func setDefaultTabWidth()
  {
    let defaultWidth = UInt(UserDefaults.standard.integer(forKey: "tabWidth"))
    
    tabWidth = (defaultWidth == 0) ? Default.tabWidth : defaultWidth
  }
}

extension WebViewController: TabWidthVariable
{
  var tabWidth: UInt
  {
    get
    {
      guard let style = webView?.mainFrameDocument.body.style,
            let tabSizeString = style.getPropertyValue("tab-size"),
            let tabSize = UInt(tabSizeString)
      else { return Default.tabWidth }
      
      return tabSize
    }
    set
    {
      guard let style = webView?.mainFrameDocument.body.style
      else { return }
      
      style.setProperty("tab-size", value: "\(newValue)", priority: "important")
      savedTabWidth = newValue
    }
  }
}

extension Wrapping
{
  var cssValue: String
  {
    switch self {
      case .none: return "pre"
      default: return "pre-wrap"
    }
  }
}

extension WebViewController: WrappingVariable
{
  public var wrapping: Wrapping
  {
    get
    {
      return savedWrapping ?? .windowWidth
    }
    set
    {
      guard let style = webView?.mainFrameDocument.body.style
      else { return }
      var wrapWidth = "100%"
      
      style.setProperty("--wrapping", value: "\(newValue.cssValue)",
                        priority: "important")
      switch newValue {
        case .columns(let columns):
          wrapWidth = "\(columns+10)ch"
        default:
          break
      }
      style.setProperty("--wrapwidth", value: wrapWidth, priority: "important")
      savedWrapping = newValue
    }
  }
}

extension WebViewController: WebFrameLoadDelegate
{
  func webView(_ sender: WebView!, didFinishLoadFor frame: WebFrame!)
  {
    if let scrollView = sender.mainFrame.frameView.documentView
                        .enclosingScrollView {
      scrollView.hasHorizontalScroller = false
      scrollView.horizontalScrollElasticity = .none
      scrollView.backgroundColor = NSColor(deviceWhite: 0.8, alpha: 1.0)
    }
    
    if let webActionDelegate = (self as? WebActionDelegateHost)?
                               .webActionDelegate {
      sender.windowScriptObject.setValue(webActionDelegate,
                                         forKey: "webActionDelegate")
    }
    
    if let savedTabWidth = self.savedTabWidth {
      tabWidth = savedTabWidth
    }
    else {
      setDefaultTabWidth()
    }
    wrapping = savedWrapping ?? PreviewsPrefsController.Default.wrapping()
    updateFont()
  }
}

let WebMenuItemTagInspectElement = 2024

extension WebViewController: WebUIDelegate
{
  static let allowedCMTags = [
      WebMenuItemTagCopy,
      WebMenuItemTagCut,
      WebMenuItemTagPaste,
      WebMenuItemTagOther,
      WebMenuItemTagSearchInSpotlight,
      WebMenuItemTagSearchWeb,
      WebMenuItemTagLookUpInDictionary,
      WebMenuItemTagOpenWithDefaultApplication,
      WebMenuItemTagInspectElement,
      ]
  
  func webView(_ sender: WebView!,
               contextMenuItemsForElement element: [AnyHashable: Any]!,
               defaultMenuItems: [Any]!) -> [Any]!
  {
    return defaultMenuItems.flatMap {
      (item) in
      guard let menuItem = item as? NSMenuItem
      else { return nil }
      
      return WebViewController.allowedCMTags.contains(menuItem.tag) ? item : nil
    }
  }
  
  func webView(_ webView: WebView!,
               dragDestinationActionMaskFor draggingInfo: NSDraggingInfo!) -> Int
  {
    return 0
  }
}
