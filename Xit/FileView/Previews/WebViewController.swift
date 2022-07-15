import Cocoa
import Combine
import WebKit

class WebViewController: NSViewController
{
  @IBOutlet weak var webView: WKWebView!
  var savedTabWidth: UInt = Default.tabWidth
  var savedWrapping: TextWrapping?
  private var appearanceObserver: NSKeyValueObservation?
  private var cancellables: [AnyCancellable] = []

  var defaults: UserDefaults = .xit

  enum Default
  {
    static var tabWidth: UInt
    { UInt(UserDefaults.xit.tabWidth) }
  }
  
  static let baseURL = Bundle.main.url(forResource: "html", withExtension: nil)!
  
  static func htmlTemplate(_ name: String) -> String
  {
    guard let htmlURL = Bundle.main.url(forResource: name,
                                        withExtension: "html",
                                        subdirectory: "html")
    else { return "" }
    
    return (try? String(contentsOf: htmlURL)) ?? ""
  }
  
  override func awakeFromNib()
  {
    webView.configuration.userContentController
           .add(self, name: "controller")
#if DEBUG
    webView.configuration.preferences
           .setValue(true, forKey: "developerExtrasEnabled")
#endif
    
    webView.setValue(false, forKey: "drawsBackground")
    cancellables.append(contentsOf: [
      defaults.publisher(for: \.fontName).sink
      { [weak self] (_) in self?.updateFont() },
      defaults.publisher(for: \.fontSize).sink
      { [weak self] (_) in self?.updateFont() },
    ])
  }
  
  override func viewDidAppear()
  {
    super.viewDidAppear()
    if appearanceObserver == nil {
      appearanceObserver = webView.observe(\.effectiveAppearance) {
        [weak self] (_, _) in
        self?.updateColors()
      }
    }
  }
  
  override func viewWillDisappear()
  {
    webView.navigationDelegate = nil
  }
  
  func updateFont()
  {
    setDocumentProperty("font-family", value: defaults.fontName)
    setDocumentProperty("font-size", value: "\(defaults.fontSize)")
  }
  
  public func load(html: String, baseURL: URL = WebViewController.baseURL)
  {
    if let webView = self.webView {
      Thread.performOnMainThread {
        webView.loadHTMLString(html, baseURL: baseURL)
      }
    }
  }
  
  public func loadNotice(_ text: UIString)
  {
    let template = WebViewController.htmlTemplate("notice")
    let escapedText = text.rawValue.xmlEscaped
    let html = String(format: template, escapedText)
    
    load(html: html)
  }
  
  func setDocumentProperty(_ property: String, value: String)
  {
    webView.evaluateJavaScript("""
        document.documentElement.style.setProperty('\(property)', '\(value)')
        """)
  }
  
  func wrappingWidthAdjustment() -> Int
  {
    return 0
  }
  
  func updateColors()
  {
    view.effectiveAppearance.performAsCurrentDrawingAppearance {
      let names = [
            "addBackground",
            "background",
            "blameBorder",
            "blameStart",
            "buttonActiveBorder",
            "buttonActiveGrad1",
            "buttonActiveGrad2",
            "buttonBorder",
            "buttonGrad1",
            "buttonGrad2",
            "deleteBackground",
            "divider",
            "heading",
            "hunkBottomBorder",
            "hunkTopBorder",
            "jumpActive",
            "jumpHoverBackground",
            "leftBackground",
            "shadow",
            ]
      let colorPairs: [(String, NSColor)] = [
        ("textColor", .textColor),
        ("textBackground", .textBackgroundColor),
        ("underPageBackgroundColor", .underPageBackgroundColor),
      ]

      for pair in colorPairs {
        setColor(name: pair.0, color: pair.1)
      }
      for name in names {
        if let color = NSColor(named: name) {
          setColor(name: name, color: color)
        }
      }
    }
  }
  
  func setColor(name: String, color: NSColor)
  {
    setDocumentProperty("--\(name)", value: color.cssRGB)
  }
  
  func webMessage(_ params: [String: Any])
  {
    // override
  }
}

extension WebViewController: WKScriptMessageHandler
{
  func userContentController(_ userContentController: WKUserContentController,
                             didReceive message: WKScriptMessage)
  {
    guard let params = message.body as? [String: Any]
    else { return }
    
    webMessage(params)
  }
}

extension WebViewController: TabWidthVariable
{
  var tabWidth: UInt
  {
    get
    { savedTabWidth }
    set
    {
      setDocumentProperty("tab-width", value: "\(newValue)")
      savedTabWidth = newValue
    }
  }
}

extension TextWrapping
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
  public var wrapping: TextWrapping
  {
    get
    { savedWrapping ?? .windowWidth }
    set
    {
      let wrapWidth: String
      
      switch newValue {
        case .columns(let columns):
          wrapWidth = "\(columns+wrappingWidthAdjustment())ch"
        default:
          wrapWidth = "100%"
      }
      setDocumentProperty("--wrapping", value: "\(newValue.cssValue) !important")
      setDocumentProperty("--wrapwidth", value: "\(wrapWidth) !important")
      savedWrapping = newValue
    }
  }
}

extension WebViewController: WKNavigationDelegate
{
  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!)
  {
    if let scrollView = webView.enclosingScrollView {
      scrollView.hasHorizontalScroller = false
      scrollView.horizontalScrollElasticity = .none
      scrollView.backgroundColor = NSColor(deviceWhite: 0.8, alpha: 1.0)
    }
    
    tabWidth = savedTabWidth
    wrapping = savedWrapping ?? defaults.wrapping
    updateFont()
    updateColors()
  }
}
