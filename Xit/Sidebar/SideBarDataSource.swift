import Cocoa
import Combine
import XitGit

/// Data source for the sidebar, showing branches, remotes, tags, stashes,
/// and submodules.
@MainActor
final class SideBarDataSource: NSObject
{
  enum Intervals
  {
    static let reloadDelay: TimeInterval = 1
  }

  @IBOutlet weak var viewController: SidebarController!
  @IBOutlet weak var outline: NSOutlineView!

  private var sinks: [AnyCancellable] = []
  
  private var activeRepoController: (any RepositoryController)?
  {
    viewController?.repoController
        ?? repoController
        ?? (repository as? XTRepository)?.controller
  }

  weak var model: SidebarDataModel! = nil
  {
    didSet
    {
      guard let repo = model.repository
      else { return }
      
      stagingItem.selection = StagingSelection(repository: repo,
                                               amending: false)
      
      if let repoController = viewController?.repoUIController?.repoController
                              ?? self.repoController {
        sinks.append(contentsOf: [
          repoController.headPublisher
            .sinkOnMainQueue {
              [weak self] in
              guard let self = self
              else { return }
              self.outline.reloadItem(self.displayItem(.branches),
                                      reloadChildren: true)
            },
          repoController.configPublisher
            .sinkOnMainQueue {
              [weak self] in
              self?.reload()
            },
          repoController.stashPublisher
            .sinkOnMainQueue {
              [weak self] in
              self?.stashChanged()
            },
        ])
      }
      reload()
    }
  }
  var filterSet: SidebarFilterSet = SidebarFilterSet(filters: [])
  var displayItemList: [SideBarGroupItem] = []
  var stagingItem: SidebarItem { model.stagingItem }

  var repository: (any SidebarDataModel.Repository)!
  { model?.repository }
  
  func setAmending(_ amending: Bool)
  {
    guard model != nil else { return }

    stagingItem.selection = StagingSelection(repository: repository,
                                             amending: amending)
    outline.reloadItem(stagingItem)
  }
  
  func displayItem(_ index: SidebarGroupIndex) -> SideBarGroupItem
  {
    return index.rawValue < displayItemList.count ?
        displayItemList[index.rawValue] :
        SideBarGroupItem(titleString: .empty) // For initial load
  }
  
  func reload()
  {
    if let queue = activeRepoController?.queue {
      queue.executeAsync {
        [weak self] in
        // Keep self weak for the dispatch call
        if let self = self {
          await Signpost.interval(.sidebarReload) {
            await self.model.reload()
          }
          await MainActor.run {
            [weak self] in
            guard self?.repository != nil
            else { return }
            self?.afterReload()
          }
        }
      }
    }
    else {
      // Fallback for tests
      Signpost.interval(.sidebarReload) {
        model.reload()
      }
      guard repository != nil
      else { return }
      afterReload()
    }
  }
  
  private func afterReload()
  {
    if displayItemList.isEmpty {
      displayItemList = filterSet.apply(to: model.roots)
      
      guard let outline = self.outline
      else { return }
      
      outline.reloadData()
      for rootItem in model.roots {
        outline.expandItem(rootItem)
      }
      for remoteItem in model.rootItem(.remotes).children {
        outline.expandItem(remoteItem)
      }
      if let currentBranch = repository.currentBranch?.name,
         currentBranch.contains("/") {
        showItem(branchName: currentBranch)
      }
    }
    else {
      applyFilterChanges()
    }
    
    if outline.selectedRow == -1 {
      selectCurrentBranch()
    }
    viewController?.reloadFinished()
  }
  
  private func applyFilterChanges()
  {
    let filteredRoots = filterSet.apply(to: model.roots)
    
    outline.beginUpdates()
    // dropFirst to skip Workspace beacuse it won't change
    for (oldGroup, newGroup) in zip(displayItemList.dropFirst(),
                                    filteredRoots.dropFirst()) {
      applyNewContents(oldRoot: oldGroup, newRoot: newGroup)
    }
    outline.endUpdates()
  }
  
  private func applyNewContents(oldRoot: SidebarItem, newRoot: SidebarItem)
  {
    let oldItems = oldRoot.children
    let newItems = newRoot.children
    let removedIndices = oldItems.indices { !newItems.containsEqualObject($0) }
    let addedIndices = newItems.indices { !oldItems.containsEqualObject($0) }
    
    outline.removeItems(at: removedIndices, inParent: oldRoot,
                        withAnimation: .effectFade)
    outline.insertItems(at: addedIndices, inParent: oldRoot,
                        withAnimation: .effectFade)
    oldRoot.children.removeObjects(at: removedIndices)
    oldRoot.children.insert(newItems.objects(at: addedIndices), at: addedIndices)
    for oldItem in oldItems where oldItem.isExpandable {
      if let newItem = newItems.first(where: { $0 == oldItem }) {
        applyNewContents(oldRoot: oldItem, newRoot: newItem)
      }
    }
  }
  
  func showItem(branchName: String)
  {
    let parts = branchName.components(separatedBy: "/")
    var parent: SidebarItem = displayItem(.branches)
    
    for part in parts {
      guard let child = parent.child(matching: part)
      else { break }
      
      outline.expandItem(child)
      parent = child
    }
  }
  
  func select(item: SidebarItem?) -> Bool
  {
    guard let item = item
    else { return false }
    let rowIndex = outline.row(forItem: item)
    
    if rowIndex != -1 {
      outline.selectRowIndexes(IndexSet(integer: rowIndex),
                               byExtendingSelection: false)
      return true
    }
    switch item {
      case is StagingSidebarItem:
        outline.selectRowIndexes(
            IndexSet(integer: outline.row(forItem: self.stagingItem)),
            byExtendingSelection: false)
        return true
      case let localItem as LocalBranchSidebarItem:
        if let item = model.item(forBranchName: localItem.title) {
          outline.selectRowIndexes(
              IndexSet(integer: outline.row(forItem: item)),
              byExtendingSelection: false)
          return true
        }
        return false
      default:
        return false
    }
  }
  
  func stashChanged()
  {
    let stashesGroup = displayItem(.stashes)

    stashesGroup.children = model.makeStashItems()
    outline.reloadItem(stashesGroup, reloadChildren: true)
    if outline.selectedRow == -1 {
      let stagingRow = outline.row(forItem: stagingItem)
      
      outline.selectRowIndexes(IndexSet(integer: stagingRow),
                               byExtendingSelection: false)
    }
  }
  
  func path(for item: SidebarItem) -> String
  {
    let title = item.displayTitle.rawValue
    
    if let parent = outline.parent(forItem: item) as? SidebarItem,
       !(parent is SideBarGroupItem) {
      return path(for: parent).appending(pathComponent: title)
    }
    else {
      return title
    }
  }
  
  func selectCurrentBranch()
  {
    _ = selectCurrentBranch(in: displayItem(.branches))
  }
  
  private func selectCurrentBranch(in parent: SidebarItem) -> Bool
  {
    for item in parent.children {
      if item.isCurrent {
        viewController?.selectedItem = item
        return true
      }
      if selectCurrentBranch(in: item) {
        return true
      }
    }
    return false
  }
}

extension SideBarDataSource: RepositoryUIAccessor
{
  var repoUIController: (any RepositoryUIController)?
  {
    guard let outline
    else { return nil }
    
    return Thread.syncOnMain {
      outline.window?.windowController as? RepositoryUIController
    }
  }
}

extension SideBarDataSource: NSOutlineViewDataSource
{
  public func outlineView(_ outlineView: NSOutlineView,
                          numberOfChildrenOfItem item: Any?) -> Int
  {
    switch item {
      case nil:
        return displayItemList.count
      case let sidebarItem as SidebarItem:
        return sidebarItem.children.count
      default:
        return 0
    }
  }
  
  public func outlineView(_ outlineView: NSOutlineView,
                          isItemExpandable item: Any) -> Bool
  {
    return (item as? SidebarItem)?.isExpandable ?? false
  }
  
  public func outlineView(_ outlineView: NSOutlineView,
                          child index: Int,
                          ofItem item: Any?) -> Any
  {
    if item == nil {
      return displayItemList[index]
    }
    
    guard let sidebarItem = item as? SidebarItem,
          sidebarItem.children.count > index
    else { return SidebarItem(title: "") }
    
    return sidebarItem.children[index]
  }
}
