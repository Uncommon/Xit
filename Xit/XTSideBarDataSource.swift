import Cocoa

/// Data source for the sidebar, showing branches, remotes, tags, stashes,
/// and submodules.
class XTSideBarDataSource: NSObject
{
  struct Intervals
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
  
  var repo: XTRepository!
  {
    didSet
    {
      guard let repo = self.repo
      else { return }
      
      stagingItem.model = StagingChanges(repository: repo)
      buildStatusCache = BuildStatusCache(repository: repo)
      
      observers.addObserver(
          forName: .XTRepositoryRefsChanged,
          object: repo, queue: .main) {
        [weak self] (_) in
        self?.reload()
      }
      observers.addObserver(
          forName: .XTRepositoryRefLogChanged,
          object: repo, queue: .main) {
        [weak self] (_) in
        guard let myself = self
        else { return }
        let stashesGroup = myself.roots[XTGroupIndex.stashes.rawValue]
        
        stashesGroup.children = myself.makeStashItems()
        myself.outline.reloadItem(stashesGroup, reloadChildren: true)
      }
      observers.addObserver(
          forName: .XTRepositoryHeadChanged,
          object: repo, queue: .main) {
        [weak self] (_) in
        guard let myself = self
        else { return }
        myself.outline.reloadItem(myself.roots[XTGroupIndex.branches.rawValue],
                                  reloadChildren: true)
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
        
        item.model.map { controller.selectedModel = $0 }
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
    observers.addObserver(
        forName: NSNotification.Name.XTTeamCityStatusChanged,
        object: nil,
        queue: .main) {
      [weak self] _ in
      self?.buildStatusCache.refresh()
    }
  }
  
  func reload()
  {
    repo?.queue.executeOffMainThread {
      let newRoots = self.loadRoots()
      
      DispatchQueue.main.async {
        self.roots = newRoots
        self.outline.reloadData()
        self.outline.expandItem(nil, expandChildren: true)
        if self.outline.selectedRow == -1 {
          self.selectCurrentBranch()
        }
      }
    }
  }
  
  func makeStashItems() -> [XTSideBarItem]
  {
    return repo?.stashes().map {
      XTStashItem(title: $0.message ?? "stash",
                  model: StashChanges(repository: repo!, stash: $0))
    } ?? []
  }
  
  func loadRoots() -> [XTSideBarGroupItem]
  {
    guard let repo = self.repo
    else { return [] }
    
    let newRoots = XTSideBarDataSource.makeRoots(stagingItem)
    let branchesGroup = newRoots[XTGroupIndex.branches.rawValue]
    let localBranches = repo.localBranches().sorted(by:
          { ($0.name ?? "") < ($1.name ?? "") })
    
    for branch in localBranches {
      guard let sha = branch.sha,
            let commit = XTCommit(sha: sha, repository: repo),
            let name = branch.name?.removingPrefix("refs/heads/")
      else { continue }
      
      let model = CommitChanges(repository: repo, commit: commit)
      let branchItem = XTLocalBranchItem(title: name, model: model)
      let parent = self.parent(for: name, groupItem: branchesGroup)
      
      parent.children.append(branchItem)
    }
    
    let remoteItems = repo.remoteNames().map {
          XTRemoteItem(title: $0, repository: repo) }
    let remoteBranches = repo.remoteBranches().sorted {
          ($0.name ?? "") < ($1.name ?? "") }


    for branch in remoteBranches {
      guard let remote = remoteItems.first(where: { $0.title ==
                                                    branch.remoteName }),
            let name = branch.name?
                       .removingPrefix("refs/remotes/\(remote.title)/"),
            let remoteName = branch.remoteName,
            let oid = branch.oid,
            let commit = XTCommit(oid: oid, repository: repo)
      else { continue }
      let model = CommitChanges(repository: repo, commit: commit)
      let remoteParent = parent(for: name, groupItem: remote)
      
      remoteParent.children.append(XTRemoteBranchItem(title: name,
                                                      remote: remoteName,
                                                      model: model))
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
      self.buildStatusCache.refresh()
    }
    return newRoots
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
        self.selectedItem = item
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
  
  func item(forBranchName branch: String) -> XTLocalBranchItem?
  {
    let branches = roots[XTGroupIndex.branches.rawValue]
    let result = branches.children.first(where: { $0.title == branch })
    
    return result as? XTLocalBranchItem
  }
  
  @objc(itemNamed:inGroup:)
  func item(named name: String, inGroup group: XTGroupIndex) -> XTSideBarItem?
  {
    let group = roots[group.rawValue]
    
    return group.children.first(where: { $0.title == name })
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
    alert.informativeText =
        "The remote branch may have been merged and deleted. Do you want to " +
        "clear the tracking branch setting, or delete your local branch " +
        "\"\(item.title)\"?"
    alert.addButton(withTitle: "Clear")
    alert.addButton(withTitle: "Delete Branch")
    alert.addButton(withTitle: "Cancel")
    alert.beginSheetModal(for: outline.window!) {
      (response) in
      switch response {
        
        case NSAlertFirstButtonReturn: // Clear
          let branch = XTLocalBranch(repository: self.repo, name: item.title)
          
          branch?.trackingBranchName = nil
          self.outline.reloadItem(item)
        
        case NSAlertSecondButtonReturn: // Delete
          self.viewController.deleteBranch(item: item)
        
        default:
          break
      }
    }
  }
  
  func doubleClick(_: Any?)
  {
    if let outline = outline,
       let clickedItem = outline.item(atRow: outline.clickedRow)
                         as? XTSubmoduleItem,
       let rootPath = repo?.repoURL.path,
       let subPath = clickedItem.submodule.path {
      let subURL = URL(fileURLWithPath: rootPath.appending(
            pathComponent: subPath))
      
      NSDocumentController.shared().openDocument(
          withContentsOf: subURL, display: true,
          completionHandler: { (_, _, _) in })
    }
  }
}

extension XTSideBarDataSource: BuildStatusClient
{
  func buildStatusUpdated(branch: String, buildType: String)
  {
    scheduleReload()
  }
}

// MARK: TeamCity
extension XTSideBarDataSource: TeamCityAccessor
{
  // repo is implicitly unwrapped, so we have to have a different property
  // for TeamCityAccessor
  var repository: XTRepository { return repo }
  
  /// Returns the name of the remote for either a remote branch or a local
  /// tracking branch.
  func remoteName(forBranchItem branchItem: XTSideBarItem) -> String?
  {
    guard let repo = repo
    else { return nil }
    
    if let remoteBranchItem = branchItem as? XTRemoteBranchItem {
      return remoteBranchItem.remote
    }
    else if let localBranchItem = branchItem as? XTLocalBranchItem {
      guard let branch = XTLocalBranch(repository: repo,
                                       name: localBranchItem.title)
      else {
        NSLog("Can't get branch for branch item: \(branchItem.title)")
        return nil
      }
      
      return branch.trackingBranch?.remoteName
    }
    return nil
  }
  
  /// Returns true if the remote branch is tracked by a local branch.
  func branchHasLocalTrackingBranch(_ branch: String) -> Bool
  {
    for localBranch in repo!.localBranches() {
      if let trackingBranch = localBranch.trackingBranch,
         trackingBranch.shortName == branch {
        return true
      }
    }
    return false
  }
  
  /// Returns true if the local branch has a remote tracking branch.
  func localBranchHasTrackingBranch(_ branch: String) -> Bool
  {
    return XTLocalBranch(repository: repo!, name: branch)?.trackingBranch != nil
  }
  
  func trackingBranchStatus(for branch: String) -> TrackingBranchStatus
  {
    if let localBranch = XTLocalBranch(repository: repo, name: branch),
       let trackingBranchName = localBranch.trackingBranchName {
      return XTRemoteBranch(repository: repo,
                            name: trackingBranchName) == nil
          ? .missing(trackingBranchName)
          : .set(trackingBranchName)
    }
    else {
      return .none
    }
  }
  
  func graphText(for item: XTSideBarItem) -> String?
  {
    if item is XTLocalBranchItem,
       let localBranch = XTLocalBranch(repository: repo!, name: item.title),
       let trackingBranch = localBranch.trackingBranch,
       let graph = repo.graphBetween(localBranch: localBranch,
                                     upstreamBranch: trackingBranch) {
      var numbers = [String]()
      
      if graph.ahead > 0 {
        numbers.append("↑\(graph.ahead)")
      }
      if graph.behind > 0 {
        numbers.append("↓\(graph.behind)")
      }
      return numbers.isEmpty ? nil : numbers.joined(separator: " ")
    }
    else {
      return nil
    }
  }
  
  func statusImage(for item: XTSideBarItem) -> NSImage?
  {
    if (item is XTRemoteBranchItem) &&
       !branchHasLocalTrackingBranch(item.title) {
      return nil
    }
    
    guard let remoteName = remoteName(forBranchItem: item),
          let (_, buildTypes) = matchTeamCity(remoteName)
    else { return nil }
    
    let branchName = (item.title as NSString).lastPathComponent
    var overallSuccess: Bool?
    
    for buildType in buildTypes {
      if let status = buildStatusCache.statuses[buildType],
         let buildSuccess = status[branchName].map({ $0.status == .succeeded }) {
        overallSuccess = (overallSuccess ?? true) && buildSuccess
      }
    }
    
    if let success = overallSuccess {
      return NSImage(named: success ? NSImageNameStatusAvailable
                                    : NSImageNameStatusUnavailable)
    }
    else {
      return NSImage(named: NSImageNameStatusNone)
    }
  }
}

extension XTSideBarDataSource: NSPopoverDelegate
{
  func popoverDidClose(_ notification: Notification)
  {
    statusPopover = nil
  }
}

// MARK: NSOutlineViewDataSource
extension XTSideBarDataSource: NSOutlineViewDataSource
{
  public func outlineView(_ outlineView: NSOutlineView,
                          numberOfChildrenOfItem item: Any?) -> Int
  {
    if item == nil {
      return roots.count
    }
    return (item as? XTSideBarItem)?.children.count ?? 0
  }
  
  public func outlineView(_ outlineView: NSOutlineView,
                          isItemExpandable item: Any) -> Bool
  {
    return (item as? XTSideBarItem)?.expandable ?? false
  }
  
  public func outlineView(_ outlineView: NSOutlineView,
                          child index: Int,
                          ofItem item: Any?) -> Any
  {
    if item == nil {
      return roots[index]
    }
    
    guard let sidebarItem = item as? XTSideBarItem,
          sidebarItem.children.count > index
    else { return XTSideBarItem(title: "") }
    
    return sidebarItem.children[index]
  }
}

// MARK: NSOutlineViewDelegate
extension XTSideBarDataSource: NSOutlineViewDelegate
{
  public func outlineViewSelectionDidChange(_ notification: Notification)
  {
    guard let item = outline!.item(atRow: outline!.selectedRow)
                     as? XTSideBarItem,
          let model = item.model,
          let controller = outline!.window?.windowController
                           as? RepositoryController
    else { return }
    
    if controller.selectedModel?.shaToSelect != model.shaToSelect {
      controller.selectedModel = model
    }
  }

  public func outlineView(_ outlineView: NSOutlineView,
                          isGroupItem item: Any) -> Bool
  {
    return item is XTSideBarGroupItem
  }

  public func outlineView(_ outlineView: NSOutlineView,
                          shouldSelectItem item: Any) -> Bool
  {
    return (item as? XTSideBarItem)?.isSelectable ?? false
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
    guard let sideBarItem = item as? XTSideBarItem
    else { return nil }
    
    if item is XTSideBarGroupItem {
      guard let headerView = outlineView.make(
          withIdentifier: "HeaderCell", owner: nil) as? NSTableCellView
      else { return nil }
      
      headerView.textField?.stringValue = sideBarItem.title
      return headerView
    }
    else {
      guard let dataView = outlineView.make(
          withIdentifier: "DataCell", owner: nil) as? XTSidebarTableCellView
      else { return nil }
      
      let textField = dataView.textField!
      
      dataView.item = sideBarItem
      dataView.imageView?.image = sideBarItem.icon
      textField.stringValue = sideBarItem.displayTitle
      textField.isEditable = sideBarItem.editable
      textField.isSelectable = sideBarItem.isSelectable
      dataView.statusText.isHidden = true
      dataView.statusImage.isHidden = true
      dataView.statusButton.image = nil
      dataView.statusButton.action = nil
      if let image = statusImage(for: sideBarItem) {
        dataView.statusButton.image = image
        dataView.statusButton.target = self
        dataView.statusButton.action = #selector(self.showItemStatus(_:))
      }
      if sideBarItem is XTLocalBranchItem {
        if let statusText = graphText(for: sideBarItem) {
          dataView.statusText.title = statusText
          dataView.statusText.isHidden = false
        }
        else if dataView.statusButton.image == nil {
          switch trackingBranchStatus(for: sideBarItem.title) {
            case .none:
              break
            case .missing(let tracking):
              dataView.statusButton.image = NSImage(named: "trackingMissing")
              dataView.statusButton.toolTip = tracking + " (missing)"
              dataView.statusButton.target = self
              dataView.statusButton.action =
                  #selector(self.missingTrackingBranch(_:))
            case .set(let tracking):
              dataView.statusButton.image = NSImage(named: "tracking")
              dataView.statusButton.toolTip = tracking
          }
        }
      }
      dataView.statusButton.isHidden = dataView.statusButton.image == nil
      if sideBarItem.editable {
        textField.formatter = refFormatter
        textField.target = viewController
        textField.action =
            #selector(XTSidebarController.sidebarItemRenamed(_:))
      }
      
      let fontSize = textField.font?.pointSize ?? 12
      
      textField.font = sideBarItem.current
          ? NSFont.boldSystemFont(ofSize: fontSize)
          : NSFont.systemFont(ofSize: fontSize)

      if sideBarItem is XTStagingItem {
        let changes = sideBarItem.model!.changes
        let stagedCount =
              changes.count(where: { $0.change != .unmodified })
        let unstagedCount =
              changes.count(where: { $0.unstagedChange != .unmodified })
        
        if (stagedCount != 0) || (unstagedCount != 0) {
          dataView.statusText.title = "\(unstagedCount)▸\(stagedCount)"
          dataView.statusText.isHidden = false
        }
        else {
          dataView.statusText.isHidden = true
        }
      }
      return dataView
    }
  }
  
  public func outlineView(_ outlineView: NSOutlineView,
                          rowViewForItem item: Any) -> NSTableRowView?
  {
    if let branchItem = item as? XTLocalBranchItem,
       branchItem.current {
      return SidebarCheckedRowView()
    }
    else if let remoteBranchItem = item as? XTRemoteBranchItem,
            let branchName = repo.currentBranch,
            let currentBranch = XTLocalBranch(repository: repo,
                                              name: branchName),
            currentBranch.trackingBranchName == remoteBranchItem.remote + "/" +
                                                remoteBranchItem.title {
      let rowView = SidebarCheckedRowView(
              imageName: NSImageNameRightFacingTriangleTemplate,
              toolTip: "The active branch is tracking this remote branch")
      
      return rowView
    }
    else {
      return nil
    }
  }
}

// MARK: XTOutlineViewDelegate
extension XTSideBarDataSource : XTOutlineViewDelegate
{
  func outlineViewClickedSelectedRow(_ outline: NSOutlineView)
  {
    guard let selectedIndex = outline.selectedRowIndexes.first,
          let selection = outline.item(atRow: selectedIndex) as? XTSideBarItem
    else { return }
    
    if let controller = outline.window?.windowController
                        as? RepositoryController,
       let oldModel = controller.selectedModel,
       let newModel = selection.model,
       oldModel.shaToSelect == newModel.shaToSelect &&
       type(of: oldModel) != type(of: newModel) {
      NotificationCenter.default.post(
          name: NSNotification.Name.XTReselectModel, object: repo)
    }
    selectedItem = selection
  }
}
