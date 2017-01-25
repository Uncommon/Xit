import Foundation

class XTTextPreviewController: XTWebViewController, TabWidthVariable
{
  func load(text: String?)
  {
    let text = text ?? ""
    let lines = text.components(separatedBy: .newlines).map {
      "<div>\(XTWebViewController.escapeText($0))</div>"
    }
    let textLines = lines.joined(separator:"\n")
    let htmlTemplate = XTWebViewController.htmlTemplate("text")
    let html = String(format: htmlTemplate, textLines)
    
    webView?.mainFrame.loadHTMLString(html,
                                      baseURL: XTTextPreviewController.baseURL())
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
  }
  
  public func load(path: String!, model: XTFileChangesModel!, staged: Bool)
  {
    load(data: model.dataForFile(path, staged: staged))
  }
}
