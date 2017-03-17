import Cocoa

protocol HunkStaging
{
  func stage(hunk: GTDiffHunk)
  func unstage(hunk: GTDiffHunk)
  func discard(hunk: GTDiffHunk)
}

/// Manages a WebView for displaying text file diffs.
class XTFileDiffController: XTWebViewController,
                            WhitespaceVariable,
                            TabWidthVariable
{
  let actionDelegate: DiffActionDelegate = DiffActionDelegate()
  var stagingDelegate: HunkStaging!
  var isLoaded: Bool = false
  var staged: Bool?
  var patch: GTDiffPatch?
  
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

  override func viewDidLoad()
  {
    actionDelegate.controller = self
  }

  override func webActionDelegate() -> Any
  {
    return actionDelegate
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
  
  func button(title: String, action: String, index: UInt) -> String
  {
    return "<span class='hunkbutton' " +
           "onClick='window.webActionDelegate.\(action)(\(index))'" +
           ">\(title)</span>"
  }
  
  func reloadDiff()
  {
    patch = nil
    
    guard let diff = diffMaker?.makeDiff()
    else { return }
    
    let htmlTemplate = XTWebViewController.htmlTemplate("diff")
    var textLines = ""
    
    do {
      patch = try diff.generatePatch()
      
      guard let patch = self.patch,
            patch.hunkCount > 0
      else {
        loadNoChangesNotice()
        return
      }
      for index in 0..<patch.hunkCount {
        guard let hunk = GTDiffHunk(patch: patch, hunkIndex: index)
        else { break }
        
        if let staged = self.staged {
          textLines += "<div class='hunkhead'>\n"
          if staged {
            textLines += button(title: "Unstage", action: "unstageHunk",
                                index: index)
          }
          else {
            textLines += button(title: "Stage", action: "stageHunk",
                                index: index)
            textLines += button(title: "Discard", action: "discardHunk",
                                index: index)
          }
          textLines += "</div>\n"
        }
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
          break
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
  
  func hunk(at index: Int) -> GTDiffHunk?
  {
    guard let patch = self.patch,
          (index >= 0) && (UInt(index) < patch.hunkCount)
    else { return nil }
    
    return GTDiffHunk(patch: patch, hunkIndex: UInt(index))
  }
  
  func stageHunk(index: Int)
  {
    hunk(at: index).map { stagingDelegate.stage(hunk: $0) }
  }
  
  func unstageHunk(index: Int)
  {
    hunk(at: index).map { stagingDelegate.unstage(hunk: $0) }
  }
  
  func discardHunk(index: Int)
  {
    hunk(at: index).map { stagingDelegate.discard(hunk: $0) }
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

class DiffActionDelegate: NSObject
{
  weak var controller: XTFileDiffController!
  
  override class func isSelectorExcluded(fromWebScript selector: Selector) -> Bool
  {
    switch selector {
      case #selector(DiffActionDelegate.stageHunk(index:)),
           #selector(DiffActionDelegate.unstageHunk(index:)),
           #selector(DiffActionDelegate.discardHunk(index:)):
        return false
      default:
        return true
    }
  }
  
  override class func webScriptName(for selector: Selector) -> String
  {
    switch selector {
      case #selector(DiffActionDelegate.stageHunk(index:)):
        return "stageHunk"
      case #selector(DiffActionDelegate.unstageHunk(index:)):
        return "unstageHunk"
      case #selector(DiffActionDelegate.discardHunk(index:)):
        return "discardHunk"
      default:
        return ""
    }
  }
  
  func stageHunk(index: Int)
  {
    controller.stageHunk(index: index)
  }
  
  func unstageHunk(index: Int)
  {
    controller.unstageHunk(index: index)
  }
  
  func discardHunk(index: Int)
  {
    controller.discardHunk(index: index)
  }
}
