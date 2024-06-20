import Cocoa

protocol HunkStaging: AnyObject
{
  func stage(hunk: any DiffHunk)
  func unstage(hunk: any DiffHunk)
  func discard(hunk: any DiffHunk)
}

/// Manages a WebView for displaying text file diffs.
final class FileDiffController: WebViewController,
                                WhitespaceVariable,
                                ContextVariable
{
  weak var stagingDelegate: (any HunkStaging)?
  weak var repo: (any FileContents & CommitReferencing)?
  var stagingType: StagingType = .none
  var patch: (any Patch)?
  
  fileprivate var isLoaded_internal = false
  
  public var whitespace = UserDefaults.xit.whitespace
  {
    didSet { configureDiffMaker() }
  }
  public var contextLines = UInt(UserDefaults.xit.contextLines)
  {
    didSet { configureDiffMaker() }
  }
  var diffMaker: PatchMaker?
  {
    didSet { configureDiffMaker() }
  }

  override func wrappingWidthAdjustment() -> Int
  {
    return 12
  }

  private func configureDiffMaker()
  {
    diffMaker?.whitespace = whitespace
    diffMaker?.contextLines = contextLines
    reloadDiff()
  }

  static func hunkLine(diffLine text: String,
                       oldLine: Int32,
                       newLine: Int32) -> String
  {
    var className = "pln"
    var oldLineText = ""
    var newLineText = ""
    let escaped = text.xmlEscaped
    
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
    return """
        <div class=\(className)>\
        <span class='old' line='\(oldLineText)'></span>\
        <span class='new' line='\(newLineText)'></span>\
        <span class='text'>\(escaped)</span>\
        </div>
        """
  }
  
  func button(title: UIString, action: String, index: Int) -> String
  {
    return """
        <span class='hunkbutton' onClick='\
        window.webkit.messageHandlers.controller\
        .postMessage({"action":"\(action)","index":\(index)})'>\
        \(title.rawValue)</span>
        """
  }
  
  func hunkHeader(hunk: any DiffHunk, index: Int, lines: [String]?) -> String
  {
    guard stagingType != .none,
          let diffMaker = diffMaker
    else { return "" }
    
    var header = "<div class='hunkhead'>\n"
    
    if lines.map({ hunk.canApply(to: $0) }) ?? true {
      switch stagingType {
        case .index:
          header += button(title: .unstage, action: "unstageHunk",
                           index: index)
        case .workspace:
          header += button(title: .stage, action: "stageHunk",
                           index: index)
          header += button(title: .discard, action: "discardHunk",
                           index: index)
        default: break
      }
    }
    else {
      let notice: UIString = (diffMaker.whitespace == .showAll)
                   ? .cantApplyHunk
                   : .whitespaceChangesHidden
      
      header += "<span class='hunknotice'>\(notice.rawValue)</span>"
    }
    header += "</div>\n"
    
    return header
  }
  
  /// Returns the index/workspace counterpart blob
  func diffTargetBlob() -> (any Blob)?
  {
    guard let diffMaker = diffMaker,
          let headRef = repo?.headRef
    else { return nil }

    switch stagingType {
      case .none:
        return nil
      case .index:
        return repo?.fileBlob(ref: headRef, path: diffMaker.path)
      case .workspace:
        return repo?.stagedBlob(file: diffMaker.path)
    }
  }
  
  func reloadDiff()
  {
    guard let diffMaker = diffMaker,
          let patch = diffMaker.makePatch()
    else {
      self.patch = nil
      return
    }
    let htmlTemplate = WebViewController.htmlTemplate("diff")
    var textLines = [String]()
    
    self.patch = patch
    
    guard patch.hunkCount > 0
    else {
      loadNoChangesNotice()
      return
    }
    
    var lines: [String]?
    
    if let blob = diffTargetBlob() {
      blob.withUnsafeBytes {
        (bytes) in
        var encoding = String.Encoding.utf8
        let text = String(data: bytes, usedEncoding: &encoding)
        
        lines = text?.components(separatedBy: .newlines)
      }
    }
    
    for index in 0..<patch.hunkCount {
      guard let hunk = patch.hunk(at: index)
      else { continue }
      
      textLines.append(hunkHeader(hunk: hunk, index: index, lines: lines))
      textLines.append("<div class='hunk'>")
      hunk.enumerateLines {
        (line) in
        textLines.append(FileDiffController.hunkLine(diffLine: line.text,
                                                       oldLine: line.oldLine,
                                                       newLine: line.newLine))
      }
      textLines.append("</div>")
    }
    
    let joined = textLines.joined(separator: "\n")
    let html = htmlTemplate.replacingOccurrences(of: "%@", with: joined)
    
    load(html: html)
    isLoaded = true
  }
  
  func loadOrNotify(diffResult: PatchMaker.PatchResult?)
  {
    if let diffResult = diffResult {
      switch diffResult {
        case .noDifference:
          loadNoChangesNotice()
        case .binary:
          loadNotice(.binaryFile)
        case .diff(let diffMaker):
          self.diffMaker = diffMaker
      }
    }
    else {
      loadNoChangesNotice()
    }
  }
  
  func loadNoChangesNotice()
  {
    var notice: UIString
    
    switch stagingType {
      case .none:
        notice = .noChanges
      case .index:
        notice = .noStagedChanges
      case .workspace:
        notice = .noUnstagedChanges
    }
    loadNotice(notice)
  }
  
  func hunk(at index: Int) -> (any DiffHunk)?
  {
    guard let patch = self.patch,
          (index >= 0) && (UInt(index) < patch.hunkCount)
    else { return nil }
    
    return patch.hunk(at: index)
  }
  
  func stageHunk(index: Int)
  {
    hunk(at: index).map { stagingDelegate?.stage(hunk: $0) }
  }
  
  func unstageHunk(index: Int)
  {
    hunk(at: index).map { stagingDelegate?.unstage(hunk: $0) }
  }
  
  func discardHunk(index: Int)
  {
    NSAlert.confirm(message: .confirmDiscardHunk,
                    actionName: .discard, isDestructive: true,
                    parentWindow: view.window!) {
      guard let hunk = self.hunk(at: index)
      else { return }
      
      self.stagingDelegate?.discard(hunk: hunk)
    }
  }
  
  override nonisolated func webMessage(action: String, sha: String?, index: Int?)
  {
    guard let index
    else { return }
    
    DispatchQueue.main.async {
      [self] in
      switch action {
        case "stageHunk":
          stageHunk(index: index)
        case "unstageHunk":
          unstageHunk(index: index)
        case "discardHunk":
          discardHunk(index: index)
        default:
          break
      }
    }
  }
}

extension FileDiffController: FileContentLoading
{
  var isLoaded: Bool
  {
    get
    { withSync { isLoaded_internal } }
    set
    { withSync { isLoaded_internal = newValue } }
  }

  public func clear()
  {
    load(html: "")
    isLoaded = false
  }
  
  public func load(selection: [FileSelection])
  {
    switch selection.count {
      case 0:
        clear()
        return
      case 1:
        self.stagingType = selection[0].staging
        loadOrNotify(diffResult:
            selection[0].fileList.diffForFile(selection[0].path))
      default:
        loadNotice(.multipleItemsSelected)
    }
  }
}
