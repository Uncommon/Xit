import Foundation

final class TextPreviewController: WebViewController
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
    
    load(html: html, baseURL: TextPreviewController.baseURL)
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

extension TextPreviewController: FileContentLoading
{
  public func clear()
  {
    load(html: "")
    isLoaded = false
  }
  
  public func load(selection: [FileSelection])
  {
    switch selection.count {
      case 0:
        loadNotice(.noSelection)
      case 1:
        load(data: selection[0].fileList.dataForFile(selection[0].path))
      default:
        loadNotice(.multipleItemsSelected)
    }
  }
}
