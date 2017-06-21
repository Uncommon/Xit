import Foundation

class BlameViewController: WebViewController
{
  @IBOutlet var spinner: NSProgressIndicator!
  var isLoaded: Bool = false
  
  let actionDelegate: BlameActionDelegate
  
  weak var repoController: RepositoryController!
  {
    return view.window?.windowController as? RepositoryController
  }
  
  override init?(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?)
  {
    actionDelegate = BlameActionDelegate()
    
    super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    
    actionDelegate.controller = self
  }
  
  required init?(coder: NSCoder)
  {
    fatalError("init(coder:) has not been implemented")
  }
  
  func notAvailable()
  {
    DispatchQueue.main.async {
      [weak self] in
      self?.loadNotice("Blame not available")
    }
  }
  
  func nextColor(lastHue: inout Int) -> NSColor
  {
    let hue = CGFloat(lastHue%360)/360.0
  
    lastHue += 55
    return NSColor(calibratedHue: hue, saturation: 0.6, brightness: 0.85,
                   alpha: 1.0)
  }
  
  func loadBlame(text: String, path: String,
                 model: FileChangesModel, staged: Bool)
  {
    defer {
      DispatchQueue.main.async {
        [weak self] in
        self?.spinner.isHidden = true
        self?.spinner.stopAnimation(nil)
      }
    }
    
    guard let blame = model.blame(for: path, staged: staged)
    else {
      notAvailable()
      return
    }
    
    var htmlLines = [String]()
    let lines = text.lineComponents()
    var commitColors = [GitOID: NSColor]()
    var lastHue = 120
    let selectOID: GitOID? = model.shaToSelect.map { GitOID(sha: $0) } ?? nil
    let currentOID = selectOID ?? GitOID.zero()
    let dateFormatter = DateFormatter()
    
    dateFormatter.timeStyle = .short
    dateFormatter.dateStyle = .short
    
    commitColors[currentOID] = nextColor(lastHue: &lastHue)
    for hunk in blame.hunks {
      var color: NSColor! = commitColors[hunk.finalOID]
      
      if color == nil {
        color = nextColor(lastHue: &lastHue)
        commitColors[hunk.finalOID] = color
      }
      
      htmlLines.append(contentsOf: [
          "<tr><td class='headcell'>",
          "<div class='blamehead' style='background-color: \(color.cssHSL)'>",
          "<div class='jumpbutton' " +
          "onclick=\"window.webActionDelegate.selectSHA('" +
          hunk.finalOID.sha + "')\">‣</div>" +
          "<div class='name'>\(hunk.finalSignature.name ?? "")</div>"
          ])
      
      if hunk.lineCount > 0 {
        if hunk.finalOID.isZero {
          htmlLines.append("<div class='local'>local changes</div>")
        }
        else {
          if hunk.finalOID == currentOID {
            htmlLines.append("<div class='currentsha'>" +
                             hunk.finalOID.sha.firstSix() + "</div>")
          }
          else {
            htmlLines.append(
                "<div>" +
                hunk.finalOID.sha.firstSix() + "</div>")
          }
        }
      }
      if hunk.lineCount > 0 {
        htmlLines.append("<div class='date'>" +
                         dateFormatter.string(from: hunk.finalSignature.when) +
                         "</div>")
      }
      if hunk.finalOID != currentOID {
        color = color.blended(withFraction: 0.65, of: .white)
      }
      htmlLines.append(contentsOf: ["</div></td>",
                                    "<td style='background-color: " +
                                    "\(color.cssHSL)'>"])
      
      let start = hunk.finalLineStart - 1
      let end = min(start + hunk.lineCount, lines.count)
      let hunkLines = lines[start..<end]
      
      htmlLines.append(contentsOf: hunkLines.map({
          "<div class='line'>" +
          "\(WebViewController.escape(text: $0))</div>" }))
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
  
  public func load(path: String!, model: FileChangesModel!, staged: Bool)
  {
    guard let data = model.dataForFile(path, staged: staged),
          let text = String(data: data, encoding: .utf8) ??
                     String(data: data, encoding: .utf16)
    else {
      notAvailable()
      return
    }
    
    spinner.isHidden = false
    spinner.startAnimation(nil)
    clear()
    DispatchQueue.global(qos: .userInitiated).async {
      [weak self] in
      self?.loadBlame(text: text, path: path, model: model, staged: staged)
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
