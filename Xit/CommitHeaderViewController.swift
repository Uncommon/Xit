import Foundation
import WebKit

@objc(XTCommitHeaderViewController)
class CommitHeaderViewController: NSViewController
{
  @IBOutlet weak var nameField: NSTextField!
  @IBOutlet weak var dateField: NSTextField!
  @IBOutlet weak var parentsLabel: NSTextField!
  @IBOutlet weak var parentsStack: NSStackView!
  @IBOutlet weak var shaLabel: NSTextField!
  @IBOutlet weak var shaField: NSTextField!
  @IBOutlet weak var messageField: NSTextField!
  
  var commitSHA: String?
  {
    didSet
    {
      loadHeader()
    }
  }
  var expanded: Bool = false
  
  weak var repoController: RepositoryController!
  {
    return view.window?.windowController as? RepositoryController
  }
  weak var repository: CommitStorage!
  
  func loadHeader()
  {
    guard let commitSHA = commitSHA,
          let commit = repository.commit(forSHA: commitSHA) as? XTCommit
    else {
      nameField.stringValue = "No selection"
      parentsLabel.stringValue = ""
      dateField.stringValue = ""
      shaLabel.isHidden = true
      messageField.stringValue = ""
      return
    }
    
    nameField.stringValue =
        "\(commit.authorName ?? "") <\(commit.authorEmail ?? "")"
    dateField.objectValue = commit.commitDate
    // separate name and date if author ≠ committer
    shaLabel.isHidden = false
    shaField.stringValue = commitSHA
    messageField.stringValue = commit.message ?? ""
    
    while let subview = parentsStack.arrangedSubviews.first {
      parentsStack.removeView(subview)
    }
    switch commit.parentOIDs.count {
      case 0:
        let noneLabel = NSTextField(labelWithString: "None")
      
        parentsStack.addArrangedSubview(noneLabel)
      case 1:
        parentsLabel.stringValue = "Parent:"
        addParents(commit)
      default:
        parentsLabel.stringValue = "Parents:"
        addParents(commit)
    }
    
    view.needsLayout = true
    
    if let scrollView = view.enclosingScrollView {
      view.scroll(NSPoint(x: 0,
                          y: scrollView.bounds.size.height))
    }
  }
  
  func addParents(_ commit: Commit)
  {
    for (index, oid) in commit.parentOIDs.enumerated() {
      guard let parentCommit = repository.commit(forOID: oid)
      else { continue }
      let message = parentCommit.messageSummary
      
      let button = ClickableTextField(title: message, target: self,
                                      action: #selector(chooseParent(_:)))
      
      button.tag = index
      parentsStack.addArrangedSubview(button)
    }
  }
  
  @IBAction
  func chooseParent(_ sender: Any?)
  {
    guard let commitSHA = commitSHA,
          let commit = repository.commit(forSHA: commitSHA) as? XTCommit,
          let control = sender as? NSControl
    else { return }
    
    let parentOID = commit.parentOIDs[control.tag]
    
    repoController.select(sha: parentOID.sha)
  }
}
