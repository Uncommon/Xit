import Foundation
import WebKit

@objc(XTCommitHeaderViewController)
class CommitHeaderViewController: NSViewController
{
  @IBOutlet weak var nameField: NSTextField!
  @IBOutlet weak var dateField: NSTextField!
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
          let commit = repository.commit(forSHA: commitSHA) as? XTCommit,
          let scrollView = view.enclosingScrollView
    else { return }
    
    view.scroll(NSPoint(x: 0,
                        y: scrollView.bounds.size.height))
    
    nameField.stringValue =
        "\(commit.authorName ?? "") <\(commit.authorEmail ?? "")"
    dateField.objectValue = commit.commitDate
    // separate name and date if author ≠ committer
    shaField.stringValue = commitSHA
    messageField.stringValue = commit.message ?? ""
    
    // set parents
  }
}
