import Cocoa

/// Manages a WebView for displaying text file diffs.
class XTFileDiffController: XTWebViewController,
                            WhitespaceVariable,
                            TabWidthVariable
{
  public var whitespace: XTWhitespace = .showAll
  public var tabWidth: UInt = 4

  static func append(diffLine text: String,
                     to lines: inout String,
                     oldLine: Int,
                     newLine: Int)
  {
    var className = "pln"
    var oldLineText = ""
    var newLineText = ""
    
    if oldLine == -1 {
      className = "add"
    }
    else {
      oldLineText = "\(oldLine)"
    }
    if newLine == -1 {
      className = "del"
    }
    else {
      newLineText = "\(newLine)"
    }
    lines += "<div class=\(className)>" +
             "<span class='old' line='\(oldLineText)'></span>" +
             "<span class='new' line='\(newLineText)'></span>" +
             "<span class='text'>\(XTWebViewController.escapeText(text))</span>" +
             "</div>\n"
  }
  
  func load(diff: XTDiffDelta)
  {
    let htmlTemplate = XTWebViewController.htmlTemplate("diff")
    var textLines = ""
    
    do {
      let patch = try diff.generatePatch()
      
      patch.enumerateHunks {
        (hunk, stop) in
        textLines += "<div class='hunk'>\n"
        do {
          try hunk.enumerateLinesInHunk {
            (line, _) in
            XTFileDiffController.append(diffLine: line.content,
                                        to: &textLines,
                                        oldLine: line.oldLineNumber,
                                        newLine: line.newLineNumber)
          }
        }
        catch let error as NSError {
          NSLog("\(error.description)")
          stop.pointee = true
        }
        textLines += "</div>\n"
      }
    }
    catch let error as NSError {
      NSLog("\(error.description)")
      return
    }
    
    let html = String(format: htmlTemplate, textLines)
    
    webView.mainFrame.loadHTMLString(html, baseURL: XTWebViewController.baseURL())
  }
  
  func loadOrNotify(diff: XTDiffDelta?)
  {
    if let diff = diff {
      load(diff: diff)
    }
    else {
      loadNotice("No changes for this selection")
    }
  }
}

extension XTFileDiffController: XTFileContentController
{
  public func clear()
  {
    webView.mainFrame.loadHTMLString("", baseURL: URL(fileURLWithPath: "/"))
  }
  
  public func load(path: String!, model: XTFileChangesModel!, staged: Bool)
  {
    loadOrNotify(diff: model.diffForFile(path, staged: staged))
  }
}
