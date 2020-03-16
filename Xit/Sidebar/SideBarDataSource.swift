import Cocoa

/// Data source for the sidebar, showing branches, remotes, tags, stashes,
/// and submodules.
class SideBarDataSource: NSObject
{
  enum Intervals
  {
    static let reloadDelay: TimeInterval = 1
  }
  
  @IBOutlet weak var viewController: SidebarController!
  @IBOutlet weak var outline: NSOutlineView!
  
  weak var model: SidebarDataModel! = nil
  {
    didSet
    {
      guard let repo = model.repository
      else { return }
      
      stagingItem.selection = StagingSelection(repository: repo)
      
      observers.addObserver(forName: .XTRepositoryRefsChanged,
                            object: repo, queue: .main) {
        [weak self] (_) in
        self?.reload()
      }
      observers.addObserver(forName: .XTRepositoryStashChanged,
                            object: repo, queue: .main) {
        [weak self] (_) in
        self?.stashChanged()
      }
      observers.addObserver(forName: .XTRepositoryHeadChanged,
                            object: repo, queue: .main) {
        [weak self] (_) in
        guard let self = self
        else { return }
        self.outline.reloadItem(self.displayItem(.branches),
                                reloadChildren: true)
      }
      observers.addObserver(forName: .XTRepositoryConfigChanged,
                            object: repo, queue: .main) {
        [weak self] (_) in
        self?.reload()
      }
      reload()
    }
  }
  var filterSet: SidebarFilterSet = SidebarFilterSet(filters: [])
  var displayItemList: [SideBarGroupItem] = []
  var stagingItem: SidebarItem { return model.stagingItem }
  
  var reloadTimer: Timer?
  
  let observers = ObserverCollection()
  
  var repository: SidebarDataModel.Repository!
  { return model?.repository }
  
  deinit
  {
    stopTimers()
  }
  
  func setAmending(_ amending: Bool)
  {
    stagingItem.selection = amending ? AmendingSelection(repository: repository)
                                     : StagingSelection(repository: repository)
    outline.reloadItem(stagingItem)
  }
  
  func displayItem(_ index: XTGroupIndex) -> SideBarGroupItem
  {
    return index.rawValue < displayItemList.count ?
        displayItemList[index.rawValue] :
        SideBarGroupItem(titleString: .emptyString) // For initial load
  }
  
  func reload()
  {
    repository.controller!.queue.executeOffMainThread {
      [weak self] in
      // Keep self weak for the dispatch call
      if let self = self {
        Signpost.interval(.sidebarReload) {
          self.model.reload()
        }
      }
      else {
        return
      }

      DispatchQueue.main.async {
        self?.afterReload()
      }
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
      if let currentBranch = repository.currentBranch,
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
    for oldItem in oldItems where oldItem.expandable {
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
      if item.current {
        viewController?.selectedItem = item
        return true
      }
      if selectCurrentBranch(in: item) {
        return true
      }
    }
    return false
  }
  
  func stopTimers()
  {
    reloadTimer?.invalidate()
  }
  
  func scheduleReload()
  {
    if let timer = reloadTimer, timer.isValid {
      timer.fireDate = Date(timeIntervalSinceNow: Intervals.reloadDelay)
    }
    else {
      reloadTimer = Timer.scheduledTimer(withTimeInterval: Intervals.reloadDelay,
                                         repeats: false) {
        [weak self] _ in
        DispatchQueue.main.async {
          guard let self = self,
                let outline = self.outline
          else { return }
          let savedSelection = self.viewController.selectedItem
          
          outline.reloadData()
          if savedSelection != nil {
            self.viewController.selectedItem = savedSelection
          }
        }
        self?.reloadTimer = nil
      }
    }
  }
}

extension SideBarDataSource: RepositoryUIAccessor
{
  var repoUIController: RepositoryUIController?
  {
    Thread.syncOnMainThread {
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
    return (item as? SidebarItem)?.expandable ?? false
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
