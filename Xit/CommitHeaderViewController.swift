import Foundation
import WebKit

protocol HeaderGenerator
{
  associatedtype Repo: RepositoryType
  associatedtype Commit: CommitType
  
  var repository: Repo! { get }
}

extension HeaderGenerator
{
  func templateURL() -> URL
  {
    return Bundle.main.url(forResource: "header",
                           withExtension: "html",
                           subdirectory: "html")!
  }

  func generateHeaderHTML(_ commit: Commit) -> String
  {
    guard let commitSHA = commit.sha
    else { return "" }
    
    // swiftlint:disable:next force_try
    let template = try! String(contentsOf: templateURL())
    let message = commit.message?.trimmingCharacters(in: .whitespacesAndNewlines)
                  ?? ""
    let authorName = commit.authorName ?? ""
    let authorEmail = commit.authorEmail ?? ""
    let authorDate = commit.authorDate
    let committerName = commit.committerName ?? ""
    let committerEmail = commit.committerEmail ?? ""
    let committerDate = commit.commitDate
    let formatter = CommitHeaderViewController.dateFormatter()
    let authorDateString = authorDate.map { formatter.string(from: $0) } ?? ""
    let committerDateString = formatter.string(from: committerDate)
    var parents = ""
    
    for parentSHA in commit.parentSHAs {
      guard let parentCommit = repository.commit(forSHA: parentSHA)
      else { continue }
      
      let summary = parentCommit.messageSummary
      let encodedSummary = CFXMLCreateStringByEscapingEntities(
        kCFAllocatorDefault, summary as CFString!, nil) as String?
      let parentText = "\(parentSHA.firstSix()) \(encodedSummary ?? "")"
      
      parents.append(
        "<div><span class=\"parent\" " +
          "onclick=\"window.webActionDelegate.selectSHA('\(parentSHA)')\">" +
        "\(parentText)</span></div>")
    }
    
    let shouldSplit = (authorName != committerName) ||
                      (authorEmail != committerEmail) ||
                      (authorDate != committerDate)
    let signatureTemplate =
          "<div%@>" +
          "<span class='name'>%@ &lt;%@&gt;</span>" +
          "%@" +
          "<span class='date'>%@</span>" +
          "</div>"
    let tagTemplate = " <span class='nametag'>(%@)</span>"
    var signature = String(format: signatureTemplate,
                           "", authorName, authorEmail,
                           shouldSplit ? String(format: tagTemplate, "author")
                                       : "",
                           authorDateString)
    
    if shouldSplit {
      signature.append("\n    ")
      signature.append(String(format: signatureTemplate,
                              " id='committer'", committerName, committerEmail,
                              shouldSplit ? String(format: tagTemplate,
                                                   "committer")
                                          : "",
                              committerDateString))
    }
    
    return String(format: template,
                  signature, commitSHA, parents, message)
  }
}

@objc(XTCommitHeaderViewController)
class CommitHeaderViewController: WebViewController, HeaderGenerator
{
  typealias Repo = XTRepository
  typealias Commit = XTCommit

  static let headerHeightKey = "height"

  var commitSHA: String?
  {
    didSet
    {
      loadHeader()
    }
  }
  var expanded: Bool = false
  
  // swiftlint:disable:next weak_delegate
  let actionDelegate: CommitHeaderActionDelegate
  
  weak var repoController: RepositoryController!
  {
    return view.window?.windowController as? RepositoryController
  }
  weak var repository: XTRepository!
  
  override init?(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?)
  {
    actionDelegate = CommitHeaderActionDelegate()
    
    super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    
    actionDelegate.controller = self
  }
  
  // required, but not actually used
  required init?(coder: NSCoder)
  {
    actionDelegate = CommitHeaderActionDelegate()
  
    super.init(coder: coder)
    
    actionDelegate.controller = self
  }
  
  static func dateFormatter() -> DateFormatter
  {
    let formatter = DateFormatter()
    
    formatter.dateStyle = .medium
    formatter.timeStyle = .medium
    return formatter
  }
  
  func isCollapsed() -> Bool
  {
    let result = webView?.windowScriptObject.callWebScriptMethod(
        "isCollapsed", withArguments: []) as AnyObject
    
    return result.boolValue ?? false
  }
  
  func loadHeader()
  {
    expanded = !isCollapsed()
    
    guard let commitSHA = commitSHA,
          let commit = repository.commit(forSHA: commitSHA)
    else { return }
    let html = generateHeaderHTML(commit)
    
    webView?.mainFrame.loadHTMLString(html, baseURL: templateURL())
  }
  
  func headerHeight() -> CGFloat
  {
    guard let webView = webView
    else { return view.frame.height }
    let savedFrame = webView.frame
    
    webView.frame = NSRect(x: 0, y: 0, width: savedFrame.size.width, height: 1)
    
    let result = webView.mainFrame.frameView.documentView.frame.size.height
    
    webView.frame = savedFrame
    return result
  }
}

extension CommitHeaderViewController: WebActionDelegateHost
{
  var webActionDelegate: Any
  {
    return actionDelegate
  }
}

extension CommitHeaderViewController // WebFrameLoadDelegate
{
  override func webView(_ sender: WebView, didFinishLoadFor frame: WebFrame)
  {
    super.webView(sender, didFinishLoadFor: frame)
    
    if !expanded {
      _ = webView?.windowScriptObject.callWebScriptMethod(
              "disclosure", withArguments: [ false, true])
    }
  }
}


extension Notification.Name
{
  static let XTHeaderResized = Notification.Name("XTHeaderResized")
}


class CommitHeaderActionDelegate: NSObject
{
  weak var controller: CommitHeaderViewController!
  
  override class func isSelectorExcluded(fromWebScript selector: Selector) -> Bool
  {
    switch selector {
      case #selector(CommitHeaderActionDelegate.select(sha:)):
        return false
      case #selector(CommitHeaderActionDelegate.headerToggled):
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
  
  func headerToggled()
  {
    let newHeight = controller.headerHeight()
    let userInfo = [CommitHeaderViewController.headerHeightKey: newHeight]
    
    NotificationCenter.default.post(name: Notification.Name.XTHeaderResized,
                                    object: controller,
                                    userInfo: userInfo)
  }
}
