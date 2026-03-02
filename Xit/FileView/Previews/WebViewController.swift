import Cocoa
import Combine
import WebKit
import XitGit

class WebViewController: NSViewController
{
  @IBOutlet weak var webView: WKWebView!
  var savedTabWidth: UInt = Default.tabWidth
  var savedWrapping: TextWrapping?
  private var userContentController: ControllerMessageHandler = .init()
  private var appearanceObserver: AnyCancellable?
  private var cancellables: [AnyCancellable] = []

  var defaults: UserDefaults = .xit

  let controllerHandlerName = "controller"

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
    
    return (try? String(contentsOf: htmlURL, encoding: .utf8)) ?? ""
  }
  
  override func awakeFromNib()
  {
    userContentController.controller = self
    webView.configuration.userContentController
           .add(userContentController, name: controllerHandlerName)
#if DEBUG
    webView.configuration.preferences
           .setValue(true, forKey: "developerExtrasEnabled")
#endif

    webView.underPageBackgroundColor = .clear
    setWebViewDrawsBackground(false)
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
    webView.navigationDelegate = self
    webView.configuration.userContentController
           .removeScriptMessageHandler(forName: controllerHandlerName)
    webView.configuration.userContentController
           .add(userContentController, name: controllerHandlerName)
    if appearanceObserver == nil {
      appearanceObserver = webView.publisher(for: \.effectiveAppearance)
                                  .sinkOnMainQueue {
        [weak self] (_) in
        self?.updateColors()
      }
    }
  }
  
  override func viewWillDisappear()
  {
    webView.navigationDelegate = nil
    webView.configuration.userContentController
           .removeScriptMessageHandler(forName: controllerHandlerName)
  }
  
  func updateFont()
  {
    setDocumentProperty("font-family", value: defaults.fontName)
    setDocumentProperty("font-size", value: "\(defaults.fontSize)")
  }
  
  public func load(html: String, baseURL: URL = WebViewController.baseURL)
  {
    if let webView = self.webView {
      DispatchQueue.main.async {
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

  func setWebViewDrawsBackground(_ draws: Bool)
  {
    // WKWebView still defaults to an opaque white page fill. Keep this
    // explicit so the web previews can participate in liquid-glass layering.
    webView.setValue(draws, forKey: "drawsBackground")
  }
  
  func wrappingWidthAdjustment() -> Int
  {
    return 0
  }
  
  func updateColors()
  {
    view.effectiveAppearance.performAsCurrentDrawingAppearance {
      let reduceTransparency = LiquidGlassAccessibility.shouldReduceTransparency
      let increaseContrast = LiquidGlassAccessibility.shouldIncreaseContrast
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
      ]

      for pair in colorPairs {
        setColor(name: pair.0, color: pair.1)
      }
      for name in names {
        if let color = NSColor(named: name) {
          setColor(name: name, color: color)
        }
      }

      if reduceTransparency {
        let fallback = NSColor.xtLiquidGlassFallbackFill

        setDocumentProperty("--underPageBackgroundColor", value: fallback.cssRGBA)
        setDocumentProperty("--background", value: fallback.cssRGBA)
      }
      else {
        // Keep the HTML surfaces translucent so the parent liquid glass
        // container remains visible through the web content.
        let surfaceAlpha = increaseContrast ? 0.9 : 0.55
        let sideAlpha = increaseContrast ? 0.85 : 0.45
        let headerAlpha = increaseContrast ? 0.9 : 0.5
        let borderAlpha = increaseContrast ? 0.8 : 0.35

        setDocumentProperty("--underPageBackgroundColor", value: "transparent")
        setDocumentProperty("--background", value: "transparent")
        setDocumentProperty("--textBackground", value:
            NSColor.textBackgroundColor.withAlphaComponent(surfaceAlpha).cssRGBA)
        setDocumentProperty("--leftBackground", value:
            NSColor.windowBackgroundColor.withAlphaComponent(sideAlpha).cssRGBA)
        setDocumentProperty("--heading", value:
            NSColor.windowBackgroundColor.withAlphaComponent(headerAlpha).cssRGBA)
        setDocumentProperty("--blameBorder", value:
            NSColor.separatorColor.withAlphaComponent(borderAlpha).cssRGBA)
      }
    }
  }
  
  func setColor(name: String, color: NSColor)
  {
    setDocumentProperty("--\(name)", value: color.cssRGB)
  }
  
  nonisolated func webMessage(_ params: [String: Any])
  {
    guard let action = params["action"] as? String
    else { return }

    webMessage(action: action, sha: (params["sha"] as? String).flatMap { SHA($0) },
               index: params["index"] as? Int)
  }

  nonisolated func webMessage(action: String, sha: SHA?, index: Int?)
  {
    // override
  }

  // This is a separate object so the web view doesn't have a strong reference
  // back to the WebViewController, creating a cycle.
  class ControllerMessageHandler: NSObject, WKScriptMessageHandler
  {
    weak var controller: WebViewController?

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage)
    {
      guard let params = message.body as? [String: Any]
      else { return }

      controller?.webMessage(params)
    }
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
  nonisolated
  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!)
  {
    DispatchQueue.main.async {
      [self] in
      if let scrollView = webView.enclosingScrollView {
        scrollView.hasHorizontalScroller = false
        scrollView.horizontalScrollElasticity = .none
        if LiquidGlassAccessibility.shouldReduceTransparency {
          scrollView.drawsBackground = true
          scrollView.backgroundColor = .xtLiquidGlassFallbackFill
          scrollView.contentView.drawsBackground = true
          setWebViewDrawsBackground(true)
          webView.underPageBackgroundColor = .xtLiquidGlassFallbackFill
        }
        else {
          scrollView.drawsBackground = false
          scrollView.backgroundColor = .clear
          scrollView.contentView.drawsBackground = false
          setWebViewDrawsBackground(false)
          webView.underPageBackgroundColor = .clear
        }
      }

      tabWidth = savedTabWidth
      wrapping = savedWrapping ?? defaults.wrapping
      updateFont()
      updateColors()
    }
  }
}
