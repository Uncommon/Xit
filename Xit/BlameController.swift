import Foundation

class BlameController: XTWebViewController, TabWidthVariable
{
}

extension BlameController: XTFileContentController
{
  func clear()
  {
    webView?.mainFrame.loadHTMLString("", baseURL: nil)
  }
  
  public func load(path: String!, model: XTFileChangesModel!, staged: Bool)
  {
    guard let data = model.dataForFile(path, staged: staged),
          let text = String(data: data, encoding: .utf8) ??
                     String(data: data, encoding: .utf16),
          let blame = (model as? Blaming)?.blame(for: path)
    else {
      loadNotice("Blame not available")
      return
    }
    
    var htmlLines = [String]()
    let lines = text.components(separatedBy: .newlines)
    
    for hunk in blame.hunks {
      htmlLines.append(contentsOf: [
          "<tr><td class='blamehead'>\(hunk.finalSignature.name ?? "")</td>",
          "<td>"
          ])
      
      let start = hunk.finalLineStart - 1
      let hunkLines = lines[start..<start+hunk.lineCount]
      
      htmlLines.append(contentsOf: hunkLines.map {
          "<div class='line'>\(XTWebViewController.escapeText($0))</div>" })
      htmlLines.append("</td></tr>")
    }
    
    let htmlTemplate = XTWebViewController.htmlTemplate("blame")
    let html = String(format: htmlTemplate, htmlLines.joined(separator: "\n"))
    
    webView?.mainFrame.loadHTMLString(html,
                                      baseURL: XTWebViewController.baseURL())
  }
}
