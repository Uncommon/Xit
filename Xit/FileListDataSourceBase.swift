import Foundation

/// Abstract base class for file list data sources.
class FileListDataSourceBase: NSObject
{
  @IBOutlet weak var outlineView: NSOutlineView!
  @IBOutlet weak var controller: XTFileViewController!
  
  var selectionObserver, workspaceObserver: NSObjectProtocol?
  
  weak var repository: XTRepository!
  {
    didSet
    {
      (self as! FileListDataSource).reload()
      workspaceObserver = NotificationCenter.default.addObserver(
          forName: .XTRepositoryWorkspaceChanged,
          object: repository, queue: .main) {
        [weak self] (note) in
        guard let myself = self
        else { return }
        
        if myself.outlineView.dataSource === myself {
          myself.workspaceChanged(note.userInfo?[XTPathsKey] as? [String])
        }
      }
    }
  }
  weak var repoController: RepositoryController!
  {
    didSet
    {
      selectionObserver = NotificationCenter.default.addObserver(
          forName: .XTSelectedModelChanged, object: repository, queue: .main) {
        [weak self] (note) in
        guard let myself = self
        else { return }
        
        if myself.outlineView.dataSource === myself {
          (myself as? FileListDataSource)?.reload()
          myself.updateStagingView()
        }
      }
    }
  }

  deinit
  {
    [selectionObserver, workspaceObserver].forEach {
      (observer) in
      observer.map { NotificationCenter.default.removeObserver($0) }
    }
  }
  
  class func transformDisplayChange(_ change: XitChange) -> XitChange
  {
    return (change == .unmodified) ? .mixed : change
  }
  
  func workspaceChanged(_ paths: [String]?)
  {
    if repoController.selectedModel is XTStagingChanges {
      (self as! FileListDataSource).reload()
    }
  }
  
  func updateStagingView()
  {
    let unstagedColumn = outlineView.tableColumn(withIdentifier: "unstaged")
    
    unstagedColumn?.isHidden = !(repoController.selectedModel?.hasUnstaged
                                 ?? false)
  }
}


/// Methods that a file list data source must implement.
@objc(XTFileListDataSource)
protocol FileListDataSource: class
{
  var hierarchical: Bool { get }
  
  func reload()
  func fileChange(at row: Int) -> XTFileChange?
  func path(for item: Any) -> String
  func change(for item: Any) -> XitChange
  func unstagedChange(for item: Any) -> XitChange
}


/// Cell view with custom drawing for deleted files.
class FileCellView : NSTableCellView
{
  /// The change is stored to improve drawing of selected deleted files.
  var change: XitChange = .unmodified
  
  override var backgroundStyle: NSBackgroundStyle
  {
    didSet
    {
      if backgroundStyle == .dark {
        textField?.textColor = .textColor
      }
      else if change == .deleted {
        textField?.textColor = .disabledControlTextColor
      }
    }
  }
}


/// Cell view with a button rather than an image.
class TableButtonView : NSTableCellView
{
  @IBOutlet var button: NSButton!
  /// The row index is stored so we know where button clicks come from.
  var row = 0
}
