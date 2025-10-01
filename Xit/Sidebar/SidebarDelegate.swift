import Cocoa
import SwiftUI

@MainActor
final class SidebarDelegate: NSObject
{
  enum CellID
  {
    static let header = ¶"HeaderCell"
    static let data = ¶"DataCell"
  }
  
  //@IBOutlet weak var controller: SidebarController?
  @IBOutlet weak var outline: NSOutlineView!
  weak var model: SidebarDataModel?
  weak var buildStatusController: BuildStatusController?
  weak var pullRequestManager: SidebarPRManager?
  
  func graphText(for item: SidebarItem) -> String?
  {
    guard let repository = model?.repository,
          item is LocalBranchSidebarItem
    else { return nil }

    return graphText(repository, for: item)
  }

  func graphText<R>(_ repository: R,
                    for item: SidebarItem) -> String?
    where R: SidebarDataModel.Repository
  {
    guard let refName = LocalBranchRefName.named(item.title),
          let localBranch = repository.localBranch(named: refName),
          let trackingBranch = localBranch.trackingBranchName,
          let graph = repository.graphBetween(localBranch: refName,
                                              upstreamBranch: trackingBranch)
    else { return nil }
    
    var numbers = [String]()
    
    if graph.ahead > 0 {
      numbers.append("↑\(graph.ahead)")
    }
    if graph.behind > 0 {
      numbers.append("↓\(graph.behind)")
    }
    return numbers.isEmpty ? nil : numbers.joined(separator: " ")
  }

  func cell(forItem item: SidebarItem) -> SidebarTableCellView?
  {
    let row = outline.row(forItem: item)
    guard row != -1
    else { return nil }
    
    return outline.view(atColumn: 0, row: row, makeIfNecessary: false)
        as? SidebarTableCellView
  }
  
  /// Optimized search for branch cells because `NSOutlineView.row(forItem:)`
  /// doesn't know about different item types, and could waste a lot of time
  /// searching through tags and such.
  func cell(forBranchItem branchItem: BranchSidebarItem) -> SidebarTableCellView?
  {
    guard let model = self.model
    else { return nil }
    let groupItem: SideBarGroupItem
    
    switch branchItem {
      //case is LocalBranchSidebarItem:
      //  groupItem = model.rootItem(.branches)
      //case is RemoteBranchSidebarItem:
      //  groupItem = model.rootItem(.remotes)
      default:
        return nil
    }
    
    let groupRow = outline.row(forItem: groupItem)
    guard groupRow != -1
    else { return nil }
    
    for row in (groupRow+1)..<outline.numberOfRows {
      guard let item = outline.item(atRow: row) as? SidebarItem
      else { continue }
      
      if item === branchItem {
        return outline.view(atColumn: 0, row: row, makeIfNecessary: false)
            as? SidebarTableCellView
      }
      
      guard !(item is SideBarGroupItem)
      else { break }
    }
    
    return nil
  }
  
  func updateStatusImage(item: SidebarItem, cell: SidebarTableCellView?)
  {
    guard let branchItem = item as? BranchSidebarItem,
          let cell = cell ?? self.cell(forBranchItem: branchItem)
    else { return }
    
    if let image = buildStatusController?.statusImage(for: item) {
      cell.statusButton.image = image
      if let localBranchItem = item as? LocalBranchSidebarItem,
         let localBranch = localBranchItem.branchObject() as? any LocalBranch,
         let tracked = localBranch.trackingBranchName {
        cell.statusButton.toolTip = tracked.name
      }
      //cell.statusButton.target = controller
      //cell.statusButton.action = #selector(SidebarController.showItemStatus(_:))
      cell.statusButton.isEnabled = true
      cell.missingImage.isHidden = true
    }
    cell.buttonContainer.isHidden = cell.statusButton.image == nil
  }
  
  fileprivate func configureLocalBranchItem(sideBarItem: SidebarItem,
                                            dataView: SidebarTableCellView)
  {
    guard let repository = model?.repository
    else { return }
    
    dataView.missingImage.isHidden = true
    if let statusText = graphText(for: sideBarItem) {
      dataView.statusText.title = statusText
      dataView.statusText.isHidden = false
    }
    else if dataView.statusButton.image == nil {
      guard let branch = LocalBranchRefName.named(sideBarItem.title)
      else { return }
      switch repository.trackingBranchStatus(for: branch) {
        case .none:
          break
        case .missing(let tracking):
          dataView.statusButton.image = .xtCloud
          dataView.statusButton.toolTip = tracking + " (missing)"
          //dataView.statusButton.target = controller
          //dataView.statusButton.action =
          //    #selector(SidebarController.missingTrackingBranch(_:))
          dataView.missingImage.isHidden = false
          dataView.statusButton.isEnabled = true
          (dataView.statusButton.cell as? NSButtonCell)?
              .imageDimsWhenDisabled = true
        case .set(let tracking):
          dataView.statusButton.image = .xtCloud
          dataView.statusButton.toolTip = tracking
          dataView.statusButton.isEnabled = false
          (dataView.statusButton.cell as? NSButtonCell)?
              .imageDimsWhenDisabled = false
      }
    }
  }
  
  fileprivate func configureStagingItem(sideBarItem: SidebarItem,
                                        dataView: SidebarTableCellView)
  {
    let selection = sideBarItem.selection as! StagedUnstagedSelection
    let (stagedCount, unstagedCount) = selection.counts()

    dataView.statusText.setStatus(unstaged: unstagedCount, staged: stagedCount)
  }
  
  func updateVisibleCells()
  {
    outline.enumerateAvailableRowViews {
      (rowView, row) in
      guard let cellView = rowView.view(atColumn: 0) as? SidebarTableCellView,
            let item = outline.item(atRow: row) as? SidebarItem
      else { return }
      
      update(cell: cellView, item: item)
    }
  }
  
  func update(cell: SidebarTableCellView, item: SidebarItem)
  {
    cell.statusText.isHidden = true
    cell.statusButton.image = nil
    cell.statusButton.action = nil
    
    updateStatusImage(item: item, cell: cell)
    if item is LocalBranchSidebarItem {
      configureLocalBranchItem(sideBarItem: item, dataView: cell)
    }
    pullRequestManager?.updatePullRequestButton(item: item, view: cell)
    cell.buttonContainer.isHidden = cell.statusButton.image == nil
    
    let textField = cell.textField!
    let fontSize = textField.font?.pointSize ?? 12
    
    textField.font = item.isCurrent
        ? .boldSystemFont(ofSize: fontSize)
        : .systemFont(ofSize: fontSize)
    
    if item is StagingSidebarItem {
      configureStagingItem(sideBarItem: item, dataView: cell)
    }
  }
}

extension SidebarDelegate: RepositoryUIAccessor
{
  var repoUIController: RepositoryUIController?
  { outline.window?.windowController as? RepositoryUIController }
}

extension SidebarDelegate: NSOutlineViewDelegate
{
  public func outlineViewSelectionDidChange(_ notification: Notification)
  {
    guard let outline = notification.object as? NSOutlineView,
          let item = outline.item(atRow: outline.selectedRow)
                     as? SidebarItem,
          let selection = item.selection,
          let controller = repoUIController
    else { return }
    
    if controller.selection?.target != selection.target {
      controller.selection = selection
    }
  }

  public func outlineView(_ outlineView: NSOutlineView,
                          isGroupItem item: Any) -> Bool
  {
    return item is SideBarGroupItem
  }

  public func outlineView(_ outlineView: NSOutlineView,
                          shouldSelectItem item: Any) -> Bool
  {
    return (item as? SidebarItem)?.isSelectable ?? false
  }

  public func outlineView(_ outlineView: NSOutlineView,
                          heightOfRowByItem item: Any) -> CGFloat
  {
    // Using this instead of setting rowSizeStyle because that prevents text
    // from displaying as bold (for the active branch).
   return 20.0
  }

  public func outlineView(_ outlineView: NSOutlineView,
                          viewFor tableColumn: NSTableColumn?,
                          item: Any) -> NSView?
  {
    switch item {
      case let groupItem as SideBarGroupItem:
        guard let headerView = outlineView.makeView(
            withIdentifier: CellID.header, owner: nil) as? NSTableCellView
        else { return nil }
        
        headerView.textField?.stringValue = groupItem.title.uppercased()
        return headerView

      case let sidebarItem as SidebarItem:
        guard let dataView = outlineView.makeView(withIdentifier: CellID.data,
                                                  owner: nil)
                             as? SidebarTableCellView
        else { return nil }
        
        let textField = dataView.textField!
        
        dataView.prDelegate = pullRequestManager
        dataView.item = sidebarItem
        if sidebarItem.isEditable {
          //textField.target = controller
          //textField.action =
          //  #selector(SidebarController.sidebarItemRenamed(_:))
        }
        else {
          textField.target = nil
          textField.action = nil
          textField.isSelectable = false
        }
        if let tagItem = sidebarItem as? TagSidebarItem,
           tagItem.tag.type == .annotated {
          dataView.infoAction = {
            dataView.showInfoPopover(TagInfoView(tag: tagItem.tag))
          }
        }
        else {
          dataView.infoAction = nil
        }
        update(cell: dataView, item: sidebarItem)
        return dataView
      
      default:
        return nil
    }
  }
}

extension SidebarDelegate: BuildStatusDisplay
{
  func updateStatusImage(item: SidebarItem)
  {
    updateStatusImage(item: item, cell: nil)
  }
}
