import Cocoa

/// Manages a WebView for displaying text file diffs.
class XTFileDiffController: XTWebViewController,
                            WhitespaceVariable,
                            TabWidthVariable
{
  var isLoaded: Bool = false
  var staged: Bool?
  public var whitespace: XTWhitespace = .showAll
  {
    didSet
    {
      configureDiffMaker()
    }
  }
  var diffMaker: XTDiffMaker? = nil
  {
    didSet
    {
      configureDiffMaker()
    }
  }

  private func configureDiffMaker()
  {
    diffMaker?.whitespace = whitespace
    reloadDiff()
  }

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
  
  func reloadDiff()
  {
    guard let diff = diffMaker?.makeDiff()
    else { return }
    
    let htmlTemplate = XTWebViewController.htmlTemplate("diff")
    var textLines = ""
    
    do {
      let patch = try diff.generatePatch()
      
      guard patch.hunkCount > 0
      else {
        loadNoChangesNotice()
        return
      }
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
    
    webView?.mainFrame.loadHTMLString(html, baseURL: XTWebViewController.baseURL())
    isLoaded = true
  }
  
  func loadOrNotify(diffMaker: XTDiffMaker?)
  {
    if let diffMaker = diffMaker {
      self.diffMaker = diffMaker
    }
    else {
      loadNoChangesNotice()
    }
  }
  
  func loadNoChangesNotice()
  {
    var notice: String!
  
    if let staged = self.staged {
      notice = staged
          ? "No staged changes for this selection"
          : "No unstaged changes for this selection"
    }
    else {
      notice = "No changes for this selection"
    }
    loadNotice(notice)
  }
}

extension XTFileDiffController: XTFileContentController
{
  public func clear()
  {
    webView?.mainFrame.loadHTMLString("", baseURL: URL(fileURLWithPath: "/"))
    isLoaded = false
  }
  
  public func load(path: String!, model: XTFileChangesModel!, staged: Bool)
  {
    self.staged = model.hasUnstaged ? staged : nil
    loadOrNotify(diffMaker: model.diffForFile(path, staged: staged))
  }
}
