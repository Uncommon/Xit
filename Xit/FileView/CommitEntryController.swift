import Cocoa
import Combine
import XitGit

extension NSTouchBarItem.Identifier
{
  static let amend = NSTouchBarItem.Identifier("com.uncommonplace.xit.amend")
  static let commit = NSTouchBarItem.Identifier("com.uncommonplace.xit.commit")
}

/// Handles the commit message entry area.
final class CommitEntryController: NSViewController,
                                   RepositoryWindowViewController
{
  typealias Repository = BasicRepository & CommitStorage & CommitReferencing

  private weak var repo: (any Repository)!
  {
    didSet
    {
      if let controller = (repo as? XTRepository)?.controller {
        Task {
          for await _ in controller.indexPublisher.values {
            updateStagedStatus()
          }
        }
        Task {
          for await _ in controller.headPublisher.values {
            resetAmend()
          }
        }
      }
      resetMessage()
    }
  }
  private weak var config: (any Config)!
  var defaults: UserDefaults = .xit

  @IBOutlet weak var commitField: NSTextView!
  @IBOutlet weak var commitButton: NSButton!
  @IBOutlet weak var amendChcekbox: NSButton!
  @IBOutlet weak var stripCheckbox: NSButton!
  @IBOutlet weak var placeholder: NSTextField!
  @IBOutlet weak var guildLine: NSBox!
  @IBOutlet weak var guideLeadingConstraint: NSLayoutConstraint!

  private var cancellables = Set<AnyCancellable>()

  var touchBarAmendButton: NSSegmentedControl!

  var anyStaged = false
  {
    didSet
    {
      if anyStaged != oldValue {
        updateCommitButton()
      }
    }
  }

  var commitMessage: String
  {
    get
    { commitField.string }
    set
    {
      commitField.string = newValue.trimmingWhitespace
      updateCommitButton()
    }
  }

  private var characterWidth: CGFloat
  {
    let size = "W".size(withAttributes: [.font: commitField.font ?? NSFont.code])
    return size.width
  }

  func configure(repository: any Repository, config: any Config)
  {
    self.config = config
    self.repo = repository
  }
  
  override func awakeFromNib()
  {
    touchBarAmendButton = NSSegmentedControl(
        labelStrings: [.amend],
        trackingMode: .selectAny,
        target: self,
        action: #selector(touchBarToggleAmend(_:)))
    
    commitField.textContainerInset = NSSize(width: 10, height: 5)
    commitField.touchBar = makeTouchBar()
  }
  
  func commitMessageTemplate() -> String?
  {
    guard let templatePath = config.commitTemplate()
    else { return nil }
    
    return try? String(contentsOfFile: templatePath, encoding: .utf8)
  }
  
  func resetMessage()
  {
    commitMessage = commitMessageTemplate() ?? ""
  }
  
  func resetAmend()
  {
    guard defaults.resetAmend
    else { return }
    
    amendChcekbox.boolValue = false
    touchBarAmendButton.setSelected(false, forSegment: 0)
    repoUIController?.isAmending = false
  }
  
  override func viewDidLoad()
  {
    super.viewDidLoad()
    
    // The editor doesn't allow setting the font of an empty text view.
    commitField.font = placeholder.font
    
    stripCheckbox.boolValue = defaults.stripComments
    defaults.publisher(for: \.stripComments).sinkOnMainQueue {
      [weak self] in
      self?.stripCheckbox.boolValue = $0
    }
    .store(in: &cancellables)

    defaults.publisher(for: \.guideWidth).sinkOnMainQueue {
      [weak self] in
      guard let strongSelf = self
      else {
        return
      }
      
      strongSelf.guideLeadingConstraint.constant =
        strongSelf.commitField.textContainerInset.width
        + (strongSelf.commitField.textContainer?.lineFragmentPadding ?? 0)
        + strongSelf.characterWidth * CGFloat($0)
    }
    .store(in: &cancellables)

    defaults.publisher(for: \.showGuide).sinkOnMainQueue {
      [weak self] in
      self?.guildLine.isHidden = $0 == false
    }
    .store(in: &cancellables)
  }
  
  override func viewWillAppear()
  {
    updateStagedStatus()
    updateCommitButton()
    amendChcekbox.boolValue = repoUIController?.isAmending ?? false
  }
  
  @IBAction
  func commit(_ sender: NSButton)
  {
    do {
      let message = commitField.string.prettifiedMessage(
            stripComments: defaults.stripComments)
      
      try repo.commit(message: message,
                      amend: repoUIController?.isAmending ?? false)
      resetMessage()
      resetAmend()
    }
    catch {
      let alert = NSAlert(error: error as NSError)
      
      alert.beginSheetModal(for: view.window!)
    }
  }
  
  @IBAction
  func toggleAmend(_ sender: NSButton)
  {
    let newValue = sender.boolValue
  
    touchBarAmendButton.setSelected(newValue, forSegment: 0)
    if newValue {
      updateAmendingCommitMessage()
    }
    repoUIController?.isAmending = newValue
  }
  
  @IBAction func toggleStrip(_ sender: NSButton)
  {
    defaults.stripComments = sender.boolValue
  }
  
  func updateAmendingCommitMessage()
  {
    guard let headCommit = repo.headCommit as (any Commit)?,
          let headMessage = headCommit.message?.trimmingWhitespace
    else { return }

    let message = commitMessage
    
    if message.isEmpty || message == commitMessageTemplate() {
      commitMessage = headMessage
    }
    else if message != headMessage {
      guard let window = view.window
      else { return }
      let alert = NSAlert()
      
      alert.messageString = .replaceMessagePrompt
      alert.informativeString = .replaceMessageInfo
      alert.addButton(withString: .replace)
      alert.addButton(withString: .dontReplace)
      alert.beginSheetModal(for: window) {
        (response) in
        if response == .alertFirstButtonReturn {
          self.commitMessage = headMessage
        }
        self.repoUIController?.isAmending = true
      }
      return
    }
  }
  
  func updateStagedStatus()
  {
    guard let controller = view.ancestorWindow?.windowController
                           as? XTWindowController,
          let changes = controller.selection?.fileList.changes
    else {
      anyStaged = false
      return
    }
    
    anyStaged = changes.contains { $0.status != .unmodified }
  }
  
  func updateCommitButton()
  {
    let text = commitField.string
    let emptyText = text.isEmpty
    
    placeholder.isHidden = !emptyText
    
    if anyStaged {
      let whitespace = CharacterSet.whitespacesAndNewlines
      let onlyWhitespace = text.trimmingCharacters(in: whitespace).isEmpty
      
      commitButton.isEnabled = !onlyWhitespace
    }
    else {
      commitButton.isEnabled = false
    }
  }
  
  override func makeTouchBar() -> NSTouchBar?
  {
    let bar = NSTouchBar()
    
    bar.delegate = self
    bar.defaultItemIdentifiers = [.characterPicker,
                                  .flexibleSpace,
                                  .candidateList,
                                  .amend, .commit]
    
    return bar
  }
}

extension CommitEntryController: NSTextDelegate
{
  func textDidChange(_ obj: Notification)
  {
    updateCommitButton()
  }
}

extension CommitEntryController: NSTouchBarDelegate
{
  func touchBar(_ touchBar: NSTouchBar,
                makeItemForIdentifier identifier: NSTouchBarItem.Identifier)
    -> NSTouchBarItem?
  {
    switch identifier {
      
      case .amend:
        let item = NSCustomTouchBarItem(identifier: identifier)
        
        item.view = touchBarAmendButton
        return item
      
      case .commit:
        let item = NSCustomTouchBarItem(identifier: identifier)
        let button = NSButton(titleString: .commit, target: self,
                              action: #selector(commit(_:)))
        
        button.bind(.enabled, to: commitButton!,
                    withKeyPath: #keyPath(NSButton.isEnabled), options: nil)
        button.keyEquivalent = "\r"
        item.view = button
        return item
      
      default:
        return nil
    }
  }
  
  @IBAction
  func touchBarToggleAmend(_ sender: Any?)
  {
    let amend = touchBarAmendButton.isSelected(forSegment: 0)
    
    amendChcekbox.state = amend ? .on : .off
    toggleAmend(amendChcekbox)
  }
}
