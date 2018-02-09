import Foundation

class XTTextPreviewController: WebViewController
{
  var isLoaded: Bool = false
  
  override func wrappingWidthAdjustment() -> Int
  {
    return 6
  }

  func minString(_ string: String) -> String
  {
    return string.isEmpty ? "\n" : string
  }
  
  func load(text: String?)
  {
    let text = text ?? ""
    let lines = text.components(separatedBy: .newlines).map {
      "<div>\(minString($0.xmlEscaped))</div>"
    }
    let textLines = lines.joined(separator: "\n")
    let htmlTemplate = WebViewController.htmlTemplate("text")
    let html = String(format: htmlTemplate, textLines)
    
    webView?.mainFrame.loadHTMLString(html,
                                      baseURL: XTTextPreviewController.baseURL)
    isLoaded = true
  }
  
  func load(data: Data?)
  {
    guard let data = data,
          let text = String(data: data, encoding: .utf8) ??
                     String(data: data, encoding: .utf16)
    else { return }
    
    load(text: text)
  }
}

extension XTTextPreviewController: XTFileContentController
{
  public func clear()
  {
    webView?.mainFrame.loadHTMLString("", baseURL: nil)
    isLoaded = false
  }
  
  public func load(path: String!, selection: RepositorySelection!, staged: Bool)
  {
    load(data: selection.list(staged: staged).dataForFile(path))
  }
}
