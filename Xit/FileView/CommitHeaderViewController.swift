import Foundation

@objc(XTCommitHeaderViewController)
class CommitHeaderViewController: NSViewController, RepositoryUIAccessor
{
  var repoUIController: RepositoryUIController?

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
  
  var repository: CommitStorage { repoController?.repository as! CommitStorage }
  
  override func awakeFromNib()
  {
    // These IDs are in the xib but get lost at runtime
    view.setAccessibilityElement(true)
    view.setAccessibilityIdentifier("commitInfo")
    parentsStack.setAccessibilityElement(true)
    parentsStack.setAccessibilityIdentifier("parents")
    loadHeader()
  }
  
  func loadHeader()
  {
    guard let commitSHA = commitSHA,
          let commit = repository.commit(forSHA: commitSHA)
    else {
      nameField.uiStringValue = .noSelection
      parentsLabel.stringValue = ""
      dateField.stringValue = ""
      shaLabel.isHidden = true
      shaField.stringValue = ""
      messageField.stringValue = ""
      clearParents()
      return
    }
    
    if commit.authorSig == commit.committerSig {
      nameField.stringValue =
          "\(commit.authorName ?? "") <\(commit.authorEmail ?? "")>"
      dateField.objectValue = commit.commitDate
    }
    else {
      let sigs = [commit.authorSig, commit.committerSig]
      
      let author = commit.authorSig.map { UIString.author($0.nameEmail) }
      let committer = commit.committerSig.map { UIString.committer($0.nameEmail) }
      let names = [author, committer].compactMap { $0?.rawValue }

      nameField.stringValue = names.joined(separator: "\n")
      
      let dates = sigs.compactMap { $0?.when }
      let dateStrings = dates.compactMap { dateField.formatter?.string(for: $0) }
      
      dateField.stringValue = dateStrings.joined(separator: "\n")
    }
    shaLabel.isHidden = false
    shaField.stringValue = commitSHA
    messageField.stringValue =
          commit.message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    
    clearParents()
    switch commit.parentOIDs.count {
      case 0:
        let noneLabel = NSTextField(labelWithUIString: .none)
      
        parentsStack.addArrangedSubview(noneLabel)
      case 1:
        parentsLabel.uiStringValue = .parent
        addParents(commit)
      default:
        parentsLabel.uiStringValue = .parents
        addParents(commit)
    }
    
    view.needsLayout = true
    view.scroll(.zero)
  }
  
  func clearParents()
  {
    while let subview = parentsStack.arrangedSubviews.first {
      parentsStack.removeView(subview)
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
          let commit = repository.commit(forSHA: commitSHA) as? GitCommit,
          let control = sender as? NSControl
    else { return }
    
    let parentOID = commit.parentOIDs[control.tag]
    
    repoUIController?.select(sha: parentOID.sha)
  }
}

extension Signature
{
  var nameEmail: String
  {
    let email = self.email.map { "<\($0)>" } ?? ""
    let name = self.name ?? ""
    
    return [name, email].joined(separator: " ")
  }
}
