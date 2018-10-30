import Cocoa

/// Data source for the sidebar, showing branches, remotes, tags, stashes,
/// and submodules.
class SideBarDataSource: NSObject
{
  enum Intervals
  {
    static let teamCityRefresh: TimeInterval = 60 * 5
    static let pullRequestRefresh: TimeInterval = 60 * 5
    static let reloadDelay: TimeInterval = 1
  }
  
  enum TrackingBranchStatus
  {
    case none            /// No tracking branch set
    case missing(String) /// References a non-existent branch
    case set(String)     /// References a real branch
  }
  
  @IBOutlet weak var viewController: SidebarController!
  @IBOutlet weak var refFormatter: XTRefFormatter!
  @IBOutlet weak var outline: NSOutlineView!
  
  private(set) var roots: [SideBarGroupItem]
  private(set) var stagingItem: SidebarItem!
  
  var statusPopover: NSPopover?
  var buildStatusCache: BuildStatusCache!
  {
    didSet
    {
      buildStatusCache.add(client: self)
    }
  }
  var pullRequestCache: PullRequestCache!
  {
    didSet
    {
      pullRequestCache.add(client: self)
    }
  }
  
  var buildStatusTimer: Timer?
  var pullRequestTimer: Timer?
  var reloadTimer: Timer?
  
  let observers = ObserverCollection()
  
  weak var repository: XTRepository!
  {
    didSet
    {
      guard let repo = self.repository
      else { return }
      
      stagingItem.selection = StagingSelection(repository: repo)
      buildStatusCache = BuildStatusCache(branchLister: repo, remoteMgr: repo)
      pullRequestCache = PullRequestCache(repository: repo)
      
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
        self.outline.reloadItem(self.roots[XTGroupIndex.branches.rawValue],
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
  
  static func makeRoots(_ stagingItem: SidebarItem) -> [SideBarGroupItem]
  {
    let rootNames: [UIString] =
          [.workspace, .branches, .remotes, .tags, .stashes, .submodules]
    let roots = rootNames.map { SideBarGroupItem(titleString: $0) }
    
    roots[0].children.append(stagingItem)
    return roots
  }
  
  override init()
  {
    self.stagingItem = StagingSidebarItem(titleString: .staging)
    self.roots = SideBarDataSource.makeRoots(stagingItem)
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
  
  open override func awakeFromNib()
  {
    outline!.target = self
    outline!.doubleAction = #selector(SideBarDataSource.doubleClick(_:))
    if !AccountsManager.manager.accounts(ofType: .teamCity).isEmpty {
      buildStatusTimer = Timer.scheduledTimer(
          withTimeInterval: Intervals.teamCityRefresh, repeats: true) {
        [weak self] _ in
        self?.buildStatusCache.refresh()
      }
    }
    if Services.shared.allServices.contains(where: { $0 is PullRequestService }) {
      pullRequestTimer = Timer.scheduledTimer(
          withTimeInterval: Intervals.pullRequestRefresh, repeats: true) {
        [weak self] _ in
        self?.pullRequestCache.refresh()
      }
    }
    observers.addObserver(forName: .XTTeamCityStatusChanged,
                          object: nil,
                          queue: .main) {
      [weak self] _ in
      self?.buildStatusCache.refresh()
    }
  }
  
  func reload()
  {
    repository?.queue.executeOffMainThread {
      [weak self] in
      kdebug_signpost_start(Signposts.sidebarReload, 0, 0, 0, 0)
      guard let newRoots = self?.loadRoots()
      else { return }
      kdebug_signpost_end(Signposts.sidebarReload, 0, 0, 0, 0)

      DispatchQueue.main.async {
        self?.afterReload(newRoots)
      }
    }
  }
  
  func afterReload(_ newRoots: [SideBarGroupItem])
  {
    let selection = outline.item(atRow: outline.selectedRow)
                    as? SidebarItem
    
    roots = newRoots
    outline.reloadData()
    for rootItem in roots {
      outline.expandItem(rootItem)
    }
    for remoteItem in roots[XTGroupIndex.remotes.rawValue].children {
      outline.expandItem(remoteItem)
    }
    if let currentBranch = repository.currentBranch,
       currentBranch.contains("/") {
      showItem(branchName: currentBranch)
    }
    if outline.numberOfSelectedRows == 0 {
      if !(selection.map({ select(item: $0) }) ?? false) {
        selectCurrentBranch()
      }
    }
  }
  
  func showItem(branchName: String)
  {
    let parts = branchName.components(separatedBy: "/")
    var parent: SidebarItem = roots[XTGroupIndex.branches.rawValue]
    
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
        if let item = self.item(forBranchName: localItem.title) {
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
    let stashesGroup = roots[XTGroupIndex.stashes.rawValue]

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
    return repository?.stashes().map {
      StashSidebarItem(title: $0.message ?? "stash",
                  selection: StashSelection(repository: repository!, stash: $0))
    } ?? []
  }
  
  func loadRoots() -> [SideBarGroupItem]
  {
    guard let repo = repository
    else { return [] }
    
    let newRoots = SideBarDataSource.makeRoots(stagingItem)
    let branchesGroup = newRoots[XTGroupIndex.branches.rawValue]
    let localBranches = repo.localBranches().sorted { $0.name < $1.name }
    
    for branch in localBranches {
      guard let sha = branch.sha,
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
    let remoteBranches = repo.remoteBranches().sorted { $0.name < $1.name }


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
    
    if let tags = try? repo.tags().sorted(by: { $0.name < $1.name }) {
      let tagsGroup = newRoots[XTGroupIndex.tags.rawValue]
      
      for tag in tags {
        let tagItem = TagSidebarItem(tag: tag)
        let tagParent = parent(for: tag.name, groupItem: tagsGroup)
        
        tagParent.children.append(tagItem)
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
      self?.buildStatusCache.refresh()
      self?.pullRequestCache.refresh()
    }
    return newRoots
  }
  
  func rootItem(_ index: XTGroupIndex) -> SidebarItem
  {
    return roots[index.rawValue]
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
  
  func selectCurrentBranch()
  {
    _ = selectCurrentBranch(in: roots[XTGroupIndex.branches.rawValue])
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
    pullRequestTimer?.invalidate()
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
  
  func item(forBranchName branch: String) -> LocalBranchSidebarItem?
  {
    let branches = roots[XTGroupIndex.branches.rawValue]
    let result = branches.children.first { $0.title == branch }
    
    return result as? LocalBranchSidebarItem
  }
  
  func item(named name: String, inGroup group: XTGroupIndex) -> SidebarItem?
  {
    let group = roots[group.rawValue]
    
    return group.child(matching: name)
  }
  
  func item(for button: NSButton) -> SidebarItem?
  {
    var superview = button.superview
    
    while superview != nil {
      if let cellView = superview as? SidebarTableCellView {
        return cellView.item
      }
      superview = superview?.superview
    }
    
    return nil
  }
  
  @IBAction func showItemStatus(_ sender: NSButton)
  {
    guard let item = item(for: sender) as? BranchSidebarItem,
          let branch = item.branchObject()
    else { return }
    
    let statusController = BuildStatusViewController(repository: repository,
                                                     branch: branch,
                                                     cache: buildStatusCache)
    let popover = NSPopover()
    
    statusPopover = popover
    popover.contentViewController = statusController
    popover.behavior = .transient
    popover.delegate = self
    popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .maxY)
  }
  
  @IBAction func missingTrackingBranch(_ sender: NSButton)
  {
    guard let item = item(for: sender) as? LocalBranchSidebarItem
    else { return }
    
    let alert = NSAlert()
    
    alert.alertStyle = .informational
    alert.messageString = .trackingBranchMissing
    alert.informativeString = .trackingMissingInfo(item.title)
    alert.addButton(withString: .clear)
    alert.addButton(withString: .deleteBranch)
    alert.addButton(withString: .cancel)
    alert.beginSheetModal(for: outline.window!) {
      (response) in
      switch response {
        
        case .alertFirstButtonReturn: // Clear
          let branch = self.repository.localBranch(named: item.title)
          
          branch?.trackingBranchName = nil
          self.outline.reloadItem(item)
        
        case .alertSecondButtonReturn: // Delete
          self.viewController.deleteBranch(item: item)
        
        default:
          break
      }
    }
  }
  
  @objc func doubleClick(_: Any?)
  {
    if let outline = outline,
       let clickedItem = outline.item(atRow: outline.clickedRow)
                         as? SubmoduleSidebarItem,
       let rootPath = repository?.repoURL.path {
      let subURL = URL(fileURLWithPath: rootPath.appending(
            pathComponent: clickedItem.submodule.path))
      
      NSDocumentController.shared.openDocument(
          withContentsOf: subURL, display: true) { (_, _, _) in }
    }
  }
}
