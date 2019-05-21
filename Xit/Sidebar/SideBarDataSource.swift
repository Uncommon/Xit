import Cocoa

/// Data source for the sidebar, showing branches, remotes, tags, stashes,
/// and submodules.
class SideBarDataSource: NSObject
{
  enum Intervals
  {
    static let teamCityRefresh: TimeInterval = 5 * .minutes
    static let reloadDelay: TimeInterval = 1
  }
  
  private struct ExpansionCache
  {
    let localBranches, remoteBranches, tags: [String]
  }
  
  @IBOutlet weak var viewController: SidebarController!
  @IBOutlet weak var outline: NSOutlineView!
  
  private(set) var model: SidebarDataModel! = nil
  private(set) var pullRequestManager: SidebarPRManager! = nil
  private(set) var buildStatusController: BuildStatusController! = nil
  var stagingItem: SidebarItem { return model.stagingItem }
  
  var buildStatusTimer: Timer?
  var reloadTimer: Timer?
  
  let observers = ObserverCollection()
  
  weak var repository: SidebarDataModel.Repository!
  {
    get { return model?.repository }
    set
    {
      guard let repo = newValue
      else { return }
      
      model = SidebarDataModel(repository: repo, outlineView: outline)
      pullRequestManager = SidebarPRManager(model: model)
      buildStatusController = BuildStatusController(model: model, display: self)
      
      stagingItem.selection = StagingSelection(repository: repo)
      
      if Services.shared.allServices
                 .contains(where: { $0 is PullRequestService }) {
        pullRequestManager.scheduleCacheRefresh()
      }
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
        self.outline.reloadItem(self.model.rootItem(.branches),
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

  var selectedItem: SidebarItem?
  {
    get
    {
      let row = outline.selectedRow
      
      return row >= 0 ? outline.item(atRow: row) as? SidebarItem : nil
    }
    set
    {
      guard let controller = outline!.window?.windowController
                             as? RepositoryController,
            let item = newValue
      else { return }
      
      let row = outline.row(forItem: item)
      
      if row >= 0 {
        outline.selectRowIndexes(IndexSet(integer: row),
                                 byExtendingSelection: false)
        
        item.selection.map { controller.selection = $0 }
      }
    }
  }
  
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
  
  private func expandedChildNames(of item: SidebarItem) -> [String]
  {
    var result: [String] = []
    
    for childItem in item.children {
      if outline.isItemExpanded(childItem) {
        result.append(path(for: childItem))
        result.append(contentsOf: expandedChildNames(of: childItem))
      }
    }
    return result
  }
  
  private func getExpansions() -> ExpansionCache
  {
    let localItem = model.rootItem(.branches)
    let remotesItem = model.rootItem(.remotes)
    let tagsItem = model.rootItem(.tags)

    return ExpansionCache(localBranches: expandedChildNames(of: localItem),
                          remoteBranches: expandedChildNames(of: remotesItem),
                          tags: expandedChildNames(of: tagsItem))
  }
  
  func reload()
  {
    let expanded = getExpansions()
    
    repository?.queue.executeOffMainThread {
      [weak self] in
      guard let newRoots = withSignpost(.sidebarReload,
                                        call: { self?.loadRoots() })
      else { return }

      DispatchQueue.main.async {
        self?.afterReload(newRoots, expanded: expanded)
      }
    }
  }
  
  private func afterReload(_ newRoots: [SideBarGroupItem],
                           expanded: ExpansionCache)
  {
    let selection = outline.item(atRow: outline.selectedRow)
                    as? SidebarItem
    
    model.roots = newRoots
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
    if outline.numberOfSelectedRows == 0  &&
       !(selection.map({ select(item: $0) }) ?? false) {
      selectCurrentBranch()
    }
    restoreExpandedItems(expanded)
  }
  
  private func restoreExpandedItems(_ expanded: ExpansionCache)
  {
    let localItem = model.rootItem(.branches)
    let remotesItem = model.rootItem(.remotes)
    let tagsItem = model.rootItem(.tags)

    for localBranch in expanded.localBranches {
      if let branchItem = localItem.child(atPath: localBranch) {
        outline.expandItem(branchItem)
      }
    }
    for remoteBranch in expanded.remoteBranches {
      if let remoteItem = remotesItem.child(atPath: remoteBranch) {
        outline.expandItem(remoteItem)
      }
    }
    for tag in expanded.tags {
      if let tagItem = tagsItem.child(atPath: tag) {
        outline.expandItem(tagItem)
      }
    }
  }
  
  func showItem(branchName: String)
  {
    let parts = branchName.components(separatedBy: "/")
    var parent: SidebarItem = model.rootItem(.branches)
    
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
    let stashesGroup = model.rootItem(.stashes)

    stashesGroup.children = makeStashItems()
    outline.reloadItem(stashesGroup, reloadChildren: true)
    if outline.selectedRow == -1 {
      let stagingRow = outline.row(forItem: stagingItem)
      
      outline.selectRowIndexes(IndexSet(integer: stagingRow),
                               byExtendingSelection: false)
    }
  }
  
  func makeStashItems() -> [SidebarItem]
  {
    return repository?.stashes.map {
      StashSidebarItem(title: $0.message ?? "stash",
                  selection: StashSelection(repository: repository!, stash: $0))
    } ?? []
  }
  
  func loadRoots() -> [SideBarGroupItem]
  {
    guard let repo = repository
    else { return [] }
    
    let newRoots = model.makeRoots()
    let branchesGroup = newRoots[XTGroupIndex.branches.rawValue]
    let localBranches = repo.localBranches.sorted { $0.name <~ $1.name }
    
    for branch in localBranches {
      guard let sha = branch.oid?.sha,
            let commit = repo.commit(forSHA: sha)
      else { continue }
      
      let name = branch.name.removingPrefix("refs/heads/")
      let selection = CommitSelection(repository: repo, commit: commit)
      let branchItem = LocalBranchSidebarItem(title: name, selection: selection)
      let parent = self.parent(for: name, groupItem: branchesGroup)
      
      parent.children.append(branchItem)
    }
    
    let remoteItems = repo.remoteNames().map {
          RemoteSidebarItem(title: $0, repository: repo) }
    let remoteBranches = repo.remoteBranches.sorted { $0.name <~ $1.name }


    for branch in remoteBranches {
      guard let remote = remoteItems.first(where: { $0.title ==
                                                    branch.remoteName }),
            let remoteName = branch.remoteName,
            let oid = branch.oid,
            let commit = repo.commit(forOID: oid)
      else { continue }
      let name = branch.name.removingPrefix("refs/remotes/\(remote.title)/")
      let selection = CommitSelection(repository: repo, commit: commit)
      let remoteParent = parent(for: name, groupItem: remote)
      
      remoteParent.children.append(RemoteBranchSidebarItem(title: name,
                                                      remote: remoteName,
                                                      selection: selection))
    }
    
    withSignpost(.loadTags) {
      if let tags = try? repo.tags().sorted(by: { $0.name <~ $1.name }) {
        let tagsGroup = newRoots[XTGroupIndex.tags.rawValue]
        
        for tag in tags {
          let tagItem = TagSidebarItem(tag: tag)
          let tagParent = parent(for: tag.name, groupItem: tagsGroup)
          
          tagParent.children.append(tagItem)
        }
      }
    }
    
    let stashItems = makeStashItems()
    let submoduleItems = repo.submodules().map {
          SubmoduleSidebarItem(submodule: $0) }
    
    newRoots[XTGroupIndex.remotes.rawValue].children = remoteItems
    newRoots[XTGroupIndex.stashes.rawValue].children = stashItems
    newRoots[XTGroupIndex.submodules.rawValue].children = submoduleItems
    
    repo.rebuildRefsIndex()
    DispatchQueue.main.async {
      [weak self] in
      self?.buildStatusController.buildStatusCache.refresh()
      self?.pullRequestManager.pullRequestCache.refresh()
    }
    return newRoots
  }
  
  func parent(for branchPath: [String],
              under item: SidebarItem) -> SidebarItem
  {
    if branchPath.count == 1 {
      return item
    }
    
    let folderName = branchPath[0]
    
    if let child = item.children.first(where: { $0.expandable &&
                                                $0.title == folderName }) {
      return parent(for: Array(branchPath.dropFirst(1)), under: child)
    }
    
    let newItem = BranchFolderSidebarItem(title: folderName)
    
    item.children.append(newItem)
    return newItem
  }
  
  func parent(for branch: String, groupItem: SidebarItem) -> SidebarItem
  {
    return parent(for: branch.components(separatedBy: "/"), under: groupItem)
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
    _ = selectCurrentBranch(in: model.rootItem(.branches))
  }
  
  func selectCurrentBranch(in parent: SidebarItem) -> Bool
  {
    for item in parent.children {
      if item.current {
        selectedItem = item
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
    buildStatusTimer?.invalidate()
    pullRequestManager?.stopCacheRefresh()
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
          guard let sidebarDS = self,
                let outline = sidebarDS.outline
          else { return }
          let savedSelection = sidebarDS.selectedItem
          
          outline.reloadData()
          if savedSelection != nil {
            sidebarDS.selectedItem = savedSelection
          }
        }
        self?.reloadTimer = nil
      }
    }
  }
  
  func graphText(for item: SidebarItem) -> String?
  {
    guard let repository = self.repository,
          item is LocalBranchSidebarItem,
          let localBranch = repository.localBranch(named: item.title),
          let trackingBranch = localBranch.trackingBranch,
          let graph = repository.graphBetween(localBranch: localBranch,
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
}
