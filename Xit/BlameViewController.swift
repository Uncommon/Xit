import Foundation

class BlameViewController: WebViewController
{
  @IBOutlet var spinner: NSProgressIndicator!
  var isLoaded: Bool = false
  
  // swiftlint:disable:next weak_delegate
  let actionDelegate: BlameActionDelegate
  
  weak var repoController: RepositoryController!
  {
    return view.window?.windowController as? RepositoryController
  }
  
  class CommitColoring
  {
    var commitColors = [String: NSColor]()
    var lastHue = 120
    
    init(firstOID: OID)
    {
      _ = color(for: firstOID)
    }
    
    func color(for oid: OID) -> NSColor
    {
      if let color = commitColors[oid.sha] {
        return color
      }
      else {
        let hue = CGFloat(lastHue) / 360.0
        let result = NSColor(calibratedHue: hue, saturation: 0.6,
                             brightness: 0.85, alpha: 1.0)
        
        lastHue = (lastHue + 55) % 360
        commitColors[oid.sha] = result
        return result
      }
    }
  }
  
  override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?)
  {
    actionDelegate = BlameActionDelegate()
    
    super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    
    actionDelegate.controller = self
  }
  
  required init?(coder: NSCoder)
  {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func loadNotice(_ text: String)
  {
    spinner.isHidden = true
    spinner.stopAnimation(nil)
    super.loadNotice(text)
  }
  
  func notAvailable()
  {
    DispatchQueue.main.async {
      [weak self] in
      self?.loadNotice("Blame not available")
    }
  }
  
  func loadBlame(text: String, path: String,
                 selection: RepositorySelection, staged: Bool)
  {
    defer {
      DispatchQueue.main.async {
        [weak self] in
        self?.spinner.isHidden = true
        self?.spinner.stopAnimation(nil)
      }
    }
    
    let list = selection.list(staged: staged)
    guard let blame = list.blame(for: path)
    else {
      notAvailable()
      return
    }
    
    var htmlLines = [String]()
    let lines = text.lineComponents()
    let selectOID: GitOID? = selection.shaToSelect.map { GitOID(sha: $0) } ?? nil
    let currentOID = selectOID ?? GitOID.zero()
    let dateFormatter = DateFormatter()
    let coloring = CommitColoring(firstOID: currentOID)
    
    dateFormatter.timeStyle = .short
    dateFormatter.dateStyle = .short
    
    for hunk in blame.hunks {
      let finalOID = hunk.finalLine.oid as! GitOID
      var color = coloring.color(for: finalOID)
      
      htmlLines.append(contentsOf: ["""
          <tr><td class='headcell'>
            <div class='blamehead' style='background-color: \(color.cssHSL)'>
            <div class='jumpbutton' \
            onclick="window.webActionDelegate.selectSHA('\(finalOID.sha)')">
            ‣</div>
            <div class='name'>\(hunk.finalLine.signature.name ?? "")</div>
          """
          ])
      
      if hunk.lineCount > 0 {
        if hunk.finalLine.oid.isZero {
          htmlLines.append("<div class='local'>local changes</div>")
        }
        else {
          if finalOID == currentOID {
            htmlLines.append("<div class='currentsha'>" +
                             hunk.finalLine.oid.sha.firstSix() + "</div>")
          }
          else {
            htmlLines.append(
                "<div>\(hunk.finalLine.oid.sha.firstSix())</div>")
          }
        }
        htmlLines.append("""
            <div class='date'>\
            \(dateFormatter.string(from: hunk.finalLine.signature.when))</div>
            """)
      }
      if finalOID != currentOID {
        color = color.blended(withFraction: 0.65, of: .white) ?? color
      }
      htmlLines.append(contentsOf: ["</div></td>",
                                    "<td style='background-color: " +
                                    "\(color.cssHSL)'>"])
      
      let start = hunk.finalLine.start - 1
      let end = min(start + hunk.lineCount, lines.count)
      let hunkLines = lines[start..<end]
      
      htmlLines.append(contentsOf: hunkLines.map({
          "<div class='line'>\($0.xmlEscaped)</div>" }))
      htmlLines.append("</td></tr>")
    }
    
    let htmlTemplate = WebViewController.htmlTemplate("blame")
    let html = String(format: htmlTemplate, htmlLines.joined(separator: "\n"))
    
    DispatchQueue.main.async {
      [weak self] in
      self?.webView?.mainFrame.loadHTMLString(
          html, baseURL: WebViewController.baseURL)
      self?.isLoaded = true
    }
  }
}

extension BlameViewController: WebActionDelegateHost
{
  var webActionDelegate: Any
  {
    return actionDelegate
  }
}

extension BlameViewController: XTFileContentController
{
  func clear()
  {
    webView?.mainFrame.loadHTMLString("", baseURL: nil)
    isLoaded = false
  }
  
  public func load(path: String!, selection: RepositorySelection!, staged: Bool)
  {
    repoController.queue.executeOffMainThread {
      [weak self] in
      guard let myself = self
      else { return }
      let list = selection.list(staged: staged)
      guard let data = list.dataForFile(path),
            let text = String(data: data, encoding: .utf8) ??
                       String(data: data, encoding: .utf16)
      else {
        myself.notAvailable()
        return
      }
      
      Thread.performOnMainThread {
        myself.spinner.isHidden = false
        myself.spinner.startAnimation(nil)
        myself.clear()
      }
      myself.loadBlame(text: text, path: path,
                       selection: selection, staged: staged)
    }
  }
}

// Similar to CommitHeaderActionDelegate, may need a refactor
class BlameActionDelegate: NSObject
{
  weak var controller: BlameViewController?
  
  override class func isSelectorExcluded(fromWebScript selector: Selector) -> Bool
  {
    switch selector {
      case #selector(BlameActionDelegate.select(sha:)):
        return false
      default:
        return true
    }
  }
  
  override class func webScriptName(for selector: Selector) -> String
  {
    switch selector {
      case #selector(CommitHeaderActionDelegate.select(sha:)):
        return "selectSHA"
      default:
        return ""
    }
  }

  @objc(selectSHA:)
  func select(sha: String)
  {
    controller?.repoController.select(sha: sha)
  }
}
