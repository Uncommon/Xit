import Foundation

class BlameController: XTWebViewController, TabWidthVariable
{
  let repository: XTRepository! = nil
}

extension BlameController: XTFileContentController
{
  func clear()
  {
    webView?.mainFrame.loadHTMLString("", baseURL: nil)
  }
  
  public func load(path: String!, model: XTFileChangesModel!, staged: Bool)
  {
    let fullPath = repository.repoURL.path.stringByAppendingPathComponent(path)
    guard let blame = GitBlame(repository: repository, path: path,
                               from: nil, to: nil),
          let text = try? String(contentsOfFile: fullPath)
    else {
      loadNotice("Could not load blame")
      return
    }
    
    var htmlLines = [String]()
    let lines = text.components(separatedBy: .newlines)
    
    for hunk in blame.hunks {
      htmlLines.append(contentsOf: [
          "<tr><td class='blamehead'>\(hunk.finalSignature.name)</td>",
          "<td>"
          ])
      
      let start = hunk.finalLineStart - 1
      let hunkLines = lines[start...start+hunk.lineCount]
      
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
