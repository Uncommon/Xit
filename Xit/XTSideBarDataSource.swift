import Cocoa

/// Data source for the sidebar, showing branches, remotes, tags, stashes,
/// and submodules.
class XTSideBarDataSource: NSObject
{
  enum Intervals
  {
    static let teamCityRefresh: TimeInterval = 60 * 5
    static let reloadDelay: TimeInterval = 1
  }
  
  enum TrackingBranchStatus
  {
    case none            /// No tracking branch set
    case missing(String) /// References a non-existent branch
    case set(String)     /// References a real branch
  }
  
  @IBOutlet weak var viewController: XTSidebarController!
  @IBOutlet weak var refFormatter: XTRefFormatter!
  @IBOutlet weak var outline: NSOutlineView!
  
  private(set) var roots: [XTSideBarGroupItem]
  private(set) var stagingItem: XTSideBarItem!
  
  var statusPopover: NSPopover?
  var buildStatusCache: BuildStatusCache!
  {
    didSet
    {
      buildStatusCache.add(client: self)
    }
  }
  
  var buildStatusTimer: Timer?
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
        guard let myself = self
        else { return }
        myself.outline.reloadItem(myself.roots[XTGroupIndex.branches.rawValue],
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

  var selectedItem: XTSideBarItem?
  {
    get
    {
      let row = outline.selectedRow
      
      return row >= 0 ? outline.item(atRow: row) as? XTSideBarItem : nil
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
  
  static func makeRoots(_ stagingItem: XTSideBarItem) -> [XTSideBarGroupItem]
  {
    let rootNames = ["WORKSPACE", "BRANCHES", "REMOTES", "TAGS", "STASHES",
                     "SUBMODULES"]
    let roots = rootNames.map { XTSideBarGroupItem(title: $0) }
    
    roots[0].add(child: stagingItem)
    return roots
  }
  
  override init()
  {
    self.stagingItem = XTStagingItem(title: "Staging")
    self.roots = XTSideBarDataSource.makeRoots(stagingItem)
  }
  
  deinit
  {
    stopTimers()
  }
  
  open override func awakeFromNib()
  {
    outline!.target = self
    outline!.doubleAction = #selector(XTSideBarDataSource.doubleClick(_:))
    if !XTAccountsManager.manager.accounts(ofType: .teamCity).isEmpty {
      buildStatusTimer = Timer.scheduledTimer(
          withTimeInterval: Intervals.teamCityRefresh, repeats: true) {
        [weak self] _ in
        self?.buildStatusCache.refresh()
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
        guard let myself = self
        else { return }
        let selection = myself.outline.item(atRow: myself.outline.selectedRow)
                        as? XTSideBarItem
        
        myself.roots = newRoots
        myself.outline.reloadData()
        myself.outline.expandItem(nil, expandChildren: true)
        if myself.outline.numberOfSelectedRows == 0 {
          if !(selection.map({ myself.select(item: $0) }) ?? false) {
            myself.selectCurrentBranch()
          }
        }
      }
    }
  }
  
  func select(item: XTSideBarItem?) -> Bool
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
      case is XTStagingItem:
        outline.selectRowIndexes(
            IndexSet(integer: outline.row(forItem: self.stagingItem)),
            byExtendingSelection: false)
        return true
      case let localItem as XTLocalBranchItem:
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
  
  func makeStashItems() -> [XTSideBarItem]
  {
    return repository?.stashes().map {
      XTStashItem(title: $0.message ?? "stash",
                  selection: StashSelection(repository: repository!, stash: $0))
    } ?? []
  }
  
  func loadRoots() -> [XTSideBarGroupItem]
  {
    guard let repo = repository
    else { return [] }
    
    let newRoots = XTSideBarDataSource.makeRoots(stagingItem)
    let branchesGroup = newRoots[XTGroupIndex.branches.rawValue]
    let localBranches = repo.localBranches().sorted(by: { $0.name < $1.name })
    
    for branch in localBranches {
      guard let sha = branch.sha,
            let commit = repo.commit(forSHA: sha)
      else { continue }
      
      let name = branch.name.removingPrefix("refs/heads/")
      let selection = CommitSelection(repository: repo, commit: commit)
      let branchItem = XTLocalBranchItem(title: name, selection: selection)
      let parent = self.parent(for: name, groupItem: branchesGroup)
      
      parent.children.append(branchItem)
    }
    
    let remoteItems = repo.remoteNames().map {
          XTRemoteItem(title: $0, repository: repo) }
    let remoteBranches = repo.remoteBranches().sorted(by: { $0.name < $1.name })


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
      
      remoteParent.children.append(XTRemoteBranchItem(title: name,
                                                      remote: remoteName,
                                                      selection: selection))
    }
    
    if let tags = try? repo.tags().sorted(by: { $0.name < $1.name }) {
      let tagsGroup = newRoots[XTGroupIndex.tags.rawValue]
      
      for tag in tags {
        let tagItem = XTTagItem(tag: tag)
        let tagParent = parent(for: tag.name, groupItem: tagsGroup)
        
        tagParent.children.append(tagItem)
      }
    }
    
    let stashItems = makeStashItems()
    let submoduleItems = repo.submodules().map {
          XTSubmoduleItem(submodule: $0) }
    
    newRoots[XTGroupIndex.remotes.rawValue].children = remoteItems
    newRoots[XTGroupIndex.stashes.rawValue].children = stashItems
    newRoots[XTGroupIndex.submodules.rawValue].children = submoduleItems
    
    repo.rebuildRefsIndex()
    DispatchQueue.main.async {
      [weak self] in
      self?.buildStatusCache.refresh()
    }
    return newRoots
  }
  
  func rootItem(_ index: XTGroupIndex) -> XTSideBarItem
  {
    return roots[index.rawValue]
  }
  
  func parent(for branchPath: [String],
              under item: XTSideBarItem) -> XTSideBarItem
  {
    if branchPath.count == 1 {
      return item
    }
    
    let folderName = branchPath[0]
    
    if let child = item.children.first(where: { $0.expandable &&
                                                $0.title == folderName }) {
      return parent(for: Array(branchPath.dropFirst(1)), under: child)
    }
    
    let newItem = XTBranchFolderItem(title: folderName)
    
    item.add(child: newItem)
    return newItem
  }
  
  func parent(for branch: String, groupItem: XTSideBarItem) -> XTSideBarItem
  {
    return parent(for: branch.components(separatedBy: "/"), under: groupItem)
  }
  
  func selectCurrentBranch()
  {
    _ = selectCurrentBranch(in: roots[XTGroupIndex.branches.rawValue])
  }
  
  func selectCurrentBranch(in parent: XTSideBarItem) -> Bool
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
  
  func graphText(for item: XTSideBarItem) -> String?
  {
    guard let repository = self.repository,
          item is XTLocalBranchItem,
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
  
  func item(forBranchName branch: String) -> XTLocalBranchItem?
  {
    let branches = roots[XTGroupIndex.branches.rawValue]
    let result = branches.children.first(where: { $0.title == branch })
    
    return result as? XTLocalBranchItem
  }
  
  func item(named name: String, inGroup group: XTGroupIndex) -> XTSideBarItem?
  {
    let group = roots[group.rawValue]
    
    return group.child(matching: name)
  }
  
  func item(for button: NSButton) -> XTSideBarItem?
  {
    var superview = button.superview
    
    while superview != nil {
      if let cellView = superview as? XTSidebarTableCellView {
        return cellView.item
      }
      superview = superview?.superview
    }
    
    return nil
  }
  
  @IBAction func showItemStatus(_ sender: NSButton)
  {
    guard let item = item(for: sender) as? XTBranchItem,
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
    guard let item = item(for: sender) as? XTLocalBranchItem
    else { return }
    
    let alert = NSAlert()
    
    alert.alertStyle = .informational
    alert.messageText = "This branch's remote tracking branch does not exist."
    alert.informativeText = """
        The remote branch may have been merged and deleted. Do you want to \
        clear the tracking branch setting, or delete your local branch \
        "\(item.title)"?
        """
    alert.addButton(withTitle: "Clear")
    alert.addButton(withTitle: "Delete Branch")
    alert.addButton(withTitle: "Cancel")
    alert.beginSheetModal(for: outline.window!) {
      (response) in
      switch response {
        
        case .alertFirstButtonReturn: // Clear
          var branch = self.repository.localBranch(named: item.title)
          
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
                         as? XTSubmoduleItem,
       let rootPath = repository?.repoURL.path {
      let subURL = URL(fileURLWithPath: rootPath.appending(
            pathComponent: clickedItem.submodule.path))
      
      NSDocumentController.shared.openDocument(
          withContentsOf: subURL, display: true,
          completionHandler: { (_, _, _) in })
    }
  }
}

// MARK: BuildStatusClient
extension XTSideBarDataSource: BuildStatusClient
{
  func buildStatusUpdated(branch: String, buildType: String)
  {
    scheduleReload()
  }
}
