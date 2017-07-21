import Foundation

class XTTextPreviewController: WebViewController
{
  var isLoaded: Bool = false

  func load(text: String?)
  {
    let text = text ?? ""
    let lines = text.components(separatedBy: .newlines).map {
      "<div>\(WebViewController.escape(text: $0))</div>"
    }
    let textLines = lines.joined(separator:"\n")
    let htmlTemplate = WebViewController.htmlTemplate("text")
    let html = String(format: htmlTemplate, textLines)
    
    load(html: html, baseURL: XTTextPreviewController.baseURL)
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
    load(html: "")
    isLoaded = false
  }
  
  public func load(path: String!, model: FileChangesModel!, staged: Bool)
  {
    load(data: model.dataForFile(path, staged: staged))
  }
}
