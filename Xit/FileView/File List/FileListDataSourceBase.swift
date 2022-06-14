import Foundation
import Combine

/// Abstract base class for file list data sources.
@MainActor
class FileListDataSourceBase: NSObject
{
  @IBOutlet weak var outlineView: NSOutlineView!
  @IBOutlet weak var controller: FileViewController!
  let useWorkspaceList: Bool
  private var sinks: [AnyCancellable] = []

  weak var delegate: (any FileListDelegate)?

  weak var repoUIController: (any RepositoryUIController)!
  {
    didSet
    {
      (self as! FileListDataSource).reload()

      if let repoUIController = self.repoUIController {
        sinks.append(contentsOf: [
          repoUIController.repoController.workspacePublisher
            .sinkOnMainQueue {
              [weak self] (paths) in
              guard let self = self
              else { return }
              if self.outlineView?.dataSource === self {
                self.workspaceChanged(paths)
              }
            },
          repoUIController.selectionPublisher
            .sink {
              [weak self] (_) in
              guard let self = self,
                    self.outlineView?.dataSource === self,
                    self.repoUIController != nil // Otherwise it's a stale timer
              else { return }

              (self as? FileListDataSource)?.reload()
            },
        ])
      }
    }
  }
  
  class func transformDisplayChange(_ change: DeltaStatus) -> DeltaStatus
  {
    return (change == .unmodified) ? .mixed : change
  }
  
  init(useWorkspaceList: Bool)
  {
    self.useWorkspaceList = useWorkspaceList
  }

  func model(for selection: RepositorySelection) -> (any FileListModel)?
  {
    return useWorkspaceList
        ? (selection as? StagedUnstagedSelection)?.unstagedFileList
        : selection.fileList
  }
  
  func workspaceChanged(_ paths: [String]?)
  {
    if repoUIController.selection is StagingSelection {
      (self as! FileListDataSource).reload()
    }
  }
}


/// Methods that a file list data source must implement.
protocol FileListDataSource: FileListDataSourceBase
{
  func reload()
  func fileChange(at row: Int) -> FileChange?
  func path(for item: Any) -> String
  func change(for item: Any) -> DeltaStatus
}

protocol FileListDelegate: AnyObject
{
  func configure(model: any FileListModel)
}


/// Cell view with custom drawing for deleted files.
class FileCellView: NSTableCellView
{
  @IBOutlet var statusImage: NSImageView!
  
  /// The change is stored to improve drawing of selected deleted files.
  var change: DeltaStatus = .unmodified
  
  override var backgroundStyle: NSView.BackgroundStyle
  {
    didSet
    {
      if backgroundStyle == .emphasized {
        textField?.textColor = .textColor
        statusImage.image?.isTemplate = true
      }
      else {
        if change == .deleted {
          textField?.textColor = .disabledControlTextColor
        }
        statusImage.image?.isTemplate = false
      }
    }
  }
}


/// Cell view with a button rather than an image.
class TableButtonView: NSTableCellView
{
  @IBOutlet var button: NSButton!
}
