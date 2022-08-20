import Foundation
import Cocoa
import Combine
import UniformTypeIdentifiers

class FileListController: NSViewController, RepositoryWindowViewController
{
  enum ColumnID
  {
    static let action = ¶"action"
    static let file = ¶"file"
    static let hidden = ¶"hidden"
  }
  
  /// Table cell view identifiers for the file list
  enum CellViewID
  {
    static let action = ¶"action"
    static let fileCell = ¶"fileCell"
  }
  
  enum ViewSegment
  {
    static let list: Int32 = 0
    static let outline: Int32 = 1
  }

  @IBOutlet weak var listTypeIcon: NSImageView!
  @IBOutlet weak var listTypeLabel: NSTextField!
  @IBOutlet weak var viewSwitch: NSSegmentedControl!
  @IBOutlet weak var toolbarStack: NSStackView!
  @IBOutlet weak var actionButton: NSPopUpButton!
  @IBOutlet weak var outlineView: FileListView!
  {
    didSet
    {
      fileListDataSource.outlineView = outlineView
      fileTreeDataSource.outlineView = outlineView
      outlineView.dataSource = viewDataSource
      outlineView.delegate = self
      outlineView.outlineTableColumn =
          outlineView.columnObject(withIdentifier: ColumnID.hidden)
    }
  }
  
  var viewDataSource: (FileListDataSourceBase &
                       FileListDataSource &
                       NSOutlineViewDataSource)!
  {
    didSet
    {
      outlineView?.dataSource = viewDataSource
    }
  }
  
  let fileListDataSource: FileChangesDataSource
  let fileTreeDataSource: FileTreeDataSource
  
  var actionImage: NSImage? { nil }
  var pressedImage: NSImage? { nil }
  var actionButtonSelector: Selector? { nil }

  typealias Repository = any BasicRepository & FileStaging & FileContents
  
  var repository: Repository
  { repoController?.repository as! Repository }

  var optionsCancellable: AnyCancellable?

  func observeOptions(_ source: AnyPublisher<FileViewOptions, Never>)
  {
    optionsCancellable = source.assign(to: \.options, on: fileListDataSource)
  }

  required init(isWorkspace: Bool)
  {
    self.fileListDataSource = FileChangesDataSource(useWorkspaceList: isWorkspace)
    self.fileTreeDataSource = FileTreeDataSource(useWorkspaceList: isWorkspace)

    super.init(nibName: "FileListView", bundle: nil)
    
    viewDataSource = fileListDataSource
  }
  
  required init?(coder: NSCoder)
  {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func loadView()
  {
    super.loadView()
    updateButtons()

    // The FileViewController isn't available as a target in the nib
    if let sortByItem = actionButton.menu?.item(withIdentifier: ◊"sortBy" ),
       let sortMenu = sortByItem.submenu {
      for item in sortMenu.items {
        item.target = parent
        item.action = #selector(FileViewController.sortFilesBy(_:))
      }
    }
  }

  // The controller must be passed in because at this point the window isn't
  // set yet.
  func finishLoad(controller: any RepositoryUIController)
  {
    fileListDataSource.repoUIController = controller
    fileTreeDataSource.repoUIController = controller
  }
  
  // These are implemented in subclasses, and are here for convenience
  // in hooking up xib items
  @IBAction func stage(_ sender: Any) {}
  @IBAction func unstage(_ sender: Any) {}
  
  @IBAction
  func stageAll(_ sender: Any)
  {
    try? repoUIController?.repository.stageAllFiles()
  }
  
  @IBAction
  func unstageAll(_ sender: Any)
  {
    try? repoUIController?.repository.unstageAllFiles()
  }
  
  @IBAction
  func revert(_ sender: Any)
  {
    let changes = targetChanges(sender: sender)
    
    switch changes.count {
      case 0:
        break
      case 1:
        let change = changes.first!
        
        NSAlert.confirm(message: .confirmRevert(change.path.lastPathComponent),
                        actionName: .revert, isDestructive: true,
                        parentWindow: view.window!) {
          try? self.repository.revert(file: change.gitPath)
        }
      default:
        NSAlert.confirm(message: .confirmRevertMultiple,
                        actionName: .revert, isDestructive: true,
                        parentWindow: view.window!) {
          for change in changes {
            try? self.repository.revert(file: change.gitPath)
          }
        }
    }
  }
  
  @IBAction
  func showIgnored(_ sender: Any)
  {
  }
  
  @IBAction
  func open(_ sender: Any)
  {
    for change in targetChanges(sender: sender) {
      let url = repository.fileURL(change.gitPath)
      
      NSWorkspace.shared.open(url)
    }
  }
  
  @IBAction
  func showInFinder(_ sender: Any)
  {
    let changes = targetChanges(sender: sender)
    let urls = changes.compactMap { repository.fileURL($0.gitPath) }
                .filter { FileManager.default.fileExists(atPath: $0.path) }
    
    NSWorkspace.shared.activateFileViewerSelecting(urls)
  }
  
  @IBAction
  func viewSwitched(_ sender: Any)
  {
    let listView = viewSwitch.intValue == ViewSegment.list
    
    viewDataSource = listView ? fileListDataSource : fileTreeDataSource
    viewDataSource.reload()
    outlineView.outlineTableColumn = outlineView.columnObject(withIdentifier:
        listView ? ColumnID.hidden : ColumnID.file)
    outlineView.reloadData()
  }
  
  /// Subclasses may want to do something when this happens.
  func repoSelectionChanged()
  {
  }
  
  /// The file change item for the row that is the target of a context menu click
  var clickedChange: FileChange?
  {
    guard let clickedRow = outlineView.contextMenuRow,
          !outlineView.selectedRowIndexes.contains(clickedRow)
    else { return nil }
    
    return viewDataSource.fileChange(at: clickedRow)
  }
  
  /// The file change item for the selected row in the list
  var selectedChange: FileChange?
  {
    guard let index = outlineView.selectedRowIndexes.first
    else { return nil }
    
    return viewDataSource?.fileChange(at: index)
  }
  
  var selectedChanges: [FileChange]
  {
    outlineView.selectedRowIndexes.compactMap {
      viewDataSource?.fileChange(at: $0)
    }
  }
  
  /// If `sender` is a button in a file list row, retuns the file change for
  /// that row.
  func buttonChange(sender: Any?) -> FileChange?
  {
    guard let button = sender as? NSButton
    else { return nil }
    let row = outlineView.row(for: button)
    
    return viewDataSource.fileChange(at: row)
  }
  
  /// Returns the file changes that are the target of the current action,
  /// depending on how the command was selected
  func targetChanges(sender: Any? = nil) -> [FileChange]
  {
    if let single = buttonChange(sender: sender) ?? clickedChange {
      return [single]
    }
    else {
      return selectedChanges
    }
  }

  func addToolbarButton(image: NSImage,
                        toolTip: UIString,
                        target: Any? = nil,
                        action: Selector,
                        accessibilityID: String? = nil)
  {
    let button = NSButton(image: image, target: target ?? self, action: action)
  
    button.toolTip = toolTip.rawValue
    button.setFrameSize(NSSize(width: 26, height: 18))
    button.bezelStyle = .smallSquare
    button.isBordered = false
    toolbarStack.insertView(button, at: 0, in: .leading)
    button.widthAnchor.constraint(equalToConstant: 20).isActive = true
    button.setAccessibilityIdentifier(accessibilityID)
  }
  
  func toolbarButton(withAction action: Selector) -> NSButton?
  {
    return toolbarStack.subviews.firstOfType(where: {
      (button: NSButton) in button.action == action
    })
  }
  
  func updateButtons()
  {
    for button in toolbarStack.subviews.compactMap({ $0 as? NSButton })
        where button != actionButton {
      button.isEnabled = validateUserInterfaceItem(button)
    }
  }
}

extension FileListController: NSUserInterfaceValidations
{
  func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool
  {
    switch item.action {
      case #selector(showInFinder(_:)),
           #selector(open(_:)):
        return selectedChange != nil
      case #selector(FileViewController.sortFilesBy(_:)):
        if let parent = self.parent as? NSUserInterfaceValidations {
          return parent.validateUserInterfaceItem(item)
        }
        else {
          return false
        }
      default:
        return false
    }
  }
}

// MARK: NSOutlineViewDelegate
extension FileListController: NSOutlineViewDelegate
{
  func outlineView(_ outlineView: NSOutlineView,
                   viewFor tableColumn: NSTableColumn?, item: Any) -> NSView?
  {
    guard let columnID = tableColumn?.identifier
    else { return nil }
    let change = viewDataSource.change(for: item)
    
    switch columnID {
      case ColumnID.action:
        guard change != .unmodified,
              let cell = outlineView.makeView(withIdentifier: CellViewID.action,
                                              owner: self) as? TableButtonView,
              let button = cell.button as? RolloverButton
        else { break }
      
        button.rolloverImage = actionImage
        button.alternateImage = pressedImage
        button.target = self
        button.action = actionButtonSelector
        return cell
      
      case ColumnID.file:
        guard let cell = outlineView.makeView(withIdentifier: CellViewID.fileCell,
                                              owner: self) as? FileCellView
        else { break }
        let path = viewDataSource.path(for: item)

        cell.textField?.stringValue = path.lastPathComponent
        cell.imageView?.image = viewDataSource.outlineView!(outlineView,
                                                            isItemExpandable: item)
            ? NSImage(named: NSImage.folderName)
            : NSWorkspace.shared.icon(for: .fromExtension(path.pathExtension))
        
        cell.textField?.textColor = textColor(for: change,
                                              outlineView: outlineView,
                                              item: item)
        cell.change = change
        
        if let image = change.changeImage {
          cell.statusImage.image = image
          cell.statusImage.isHidden = false
        }
        else {
          cell.statusImage.isHidden = true
        }
        return cell

      default:
        break
    }
    return nil
  }
  
  func outlineViewSelectionDidChange(_ notification: Notification)
  {
    updateButtons()
  }
  
  private func textColor(for change: DeltaStatus, outlineView: NSOutlineView,
                         item: Any)
    -> NSColor
  {
    if change == .deleted {
      return NSColor.disabledControlTextColor
    }
    else if outlineView.isRowSelected(outlineView.row(forItem: item)) {
      return NSColor.selectedTextColor
    }
    else {
      return NSColor.textColor
    }
  }
}

extension DeltaStatus
{
  var changeImage: NSImage?
  {
    let info: (String, NSColor)

    switch self {
      case .added, .untracked:
        info = ("plus.circle", .systemGreen)
      case .copied:
        info = ("circlebadge.2.fill", .systemGreen)
      case .deleted:
        info = ("minus.circle", .systemRed)
      case .modified, .typeChange:
        info = ("pencil.circle", .systemBlue)
      case .renamed:
        info = ("r.circle", .systemTeal)
      case .conflict:
        info = ("exclamationmark.triangle.fill", .systemYellow)
      case .mixed:
        info = ("ellipsis.circle.fill", .systemGray)
      default:
        return nil
    }
    return NSImage(systemSymbolName: info.0)!
      .withSymbolConfiguration(.init(pointSize: 11, weight: .bold))!
      .image(coloredWith: info.1)
  }
}
