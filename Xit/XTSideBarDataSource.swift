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
  
  @IBOutlet weak var viewController: XTSidebarController!
  @IBOutlet weak var refFormatter: XTRefFormatter!
  @IBOutlet weak var outline: NSOutlineView!
  
  private(set) var roots: [XTSideBarGroupItem]
  private(set) var stagingItem: XTSideBarItem!
  
  var buildStatuses = [String: [String: Bool]]()
  
  var buildStatusTimer: Timer?
  var reloadTimer: Timer?
  
  let observers = ObserverCollection()
  
  var repo: XTRepository!
  {
    didSet
    {
      guard let repo = self.repo
      else { return }
      
      stagingItem.model = XTStagingChanges(repository: repo)
      
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
                     "SUBMODULES"];
    let roots = rootNames.map({ XTSideBarGroupItem(title: $0) })
    
    roots[0].add(child: stagingItem)
    return roots;
  }
  
  override init()
  {
    self.stagingItem = XTStagingItem(title: "Staging")
    self.roots = XTSideBarDataSource.makeRoots(stagingItem)
  }
  
  deinit
  {
    buildStatusTimer?.invalidate()
  }
  
  open override func awakeFromNib()
  {
    outline!.target = self
    outline!.doubleAction = #selector(XTSideBarDataSource.doubleClick(_:))
    if (!XTAccountsManager.manager.accounts(ofType: .teamCity).isEmpty) {
      buildStatusTimer = Timer.scheduledTimer(
          withTimeInterval: Intervals.teamCityRefresh, repeats: true) {
        [weak self] _ in
        self?.updateTeamCity()
      }
    }
    observers.addObserver(
        forName: NSNotification.Name.XTTeamCityStatusChanged,
        object: nil,
        queue: .main) {
      [weak self] _ in
      self?.updateTeamCity()
    }
  }
  
  func reload()
  {
    repo?.executeOffMainThread {
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
                  model: XTStashChanges(repository: repo!, stash: $0))
    } ?? []
  }
  
  func loadRoots() -> [XTSideBarGroupItem]
  {
    guard let repo = self.repo
    else { return [] }
    
    let newRoots = XTSideBarDataSource.makeRoots(stagingItem)
    let branchesGroup = newRoots[XTGroupIndex.branches.rawValue]
    
    for branch in repo.localBranches() {
      guard let sha = branch.sha,
            let name = branch.name?.stringByRemovingPrefix("refs/heads/")
      else { continue }
      
      let model = XTCommitChanges(repository: repo, sha: sha)
      let branchItem = XTLocalBranchItem(title: name, model: model)
      let parent = self.parent(for: name, groupItem: branchesGroup)
      
      parent.children.append(branchItem)
    }
    
    let remoteItems = repo.remoteNames().map { XTRemoteItem(title: $0,
                                                            repository: repo) }

    for branch in repo.remoteBranches() {
      guard let remote = remoteItems.first(where: { $0.title ==
                                                    branch.remoteName }),
            let name = branch.name?
                       .stringByRemovingPrefix("refs/remotes/\(remote.title)/"),
            let sha = branch.gtBranch.oid?.sha
      else { continue }
      let model = XTCommitChanges(repository: repo, sha: sha)
      let remoteParent = parent(for: name,
                                groupItem: remote)
      
      remoteParent.children.append(XTRemoteBranchItem(title: name,
                                                      remote: branch.remoteName,
                                                      model: model))
    }
    
    let tagItems = (try? repo.tags())?.map { XTTagItem(tag: $0) } ?? []
    let stashItems = makeStashItems()
    let submoduleItems = repo.submodules().map { XTSubmoduleItem(submodule: $0) }
    
    newRoots[XTGroupIndex.remotes.rawValue].children = remoteItems
    newRoots[XTGroupIndex.tags.rawValue].children = tagItems
    newRoots[XTGroupIndex.stashes.rawValue].children = stashItems
    newRoots[XTGroupIndex.submodules.rawValue].children = submoduleItems
    
    repo.rebuildRefsIndex()
    DispatchQueue.main.async {
      self.updateTeamCity()
    }
    return newRoots
  }
  
  func parent(for branchPath: [String],
              under item: XTSideBarItem) -> XTSideBarItem
  {
    if branchPath.count == 1 {
      return item
    }
    
    let folderName = branchPath[0];
    
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
    if let timer = reloadTimer , timer.isValid {
      timer.fireDate = Date(timeIntervalSinceNow: Intervals.reloadDelay)
    }
    else {
      reloadTimer = Timer.scheduledTimer(withTimeInterval: Intervals.reloadDelay,
                                         repeats: false) {
        [weak self] _ in
        guard let sidebarDS = self
        else { return }
        
        DispatchQueue.main.async {
          let savedSelection = sidebarDS.selectedItem
          
          sidebarDS.outline!.reloadData()
          if savedSelection != nil {
            sidebarDS.selectedItem = savedSelection
          }
        }
        sidebarDS.reloadTimer = nil
      }
    }
  }
  
  func item(forBranchName branch: String) -> XTLocalBranchItem?
  {
    let branches = roots[XTGroupIndex.branches.rawValue]
    let result = branches.children.first(where: { $0.title == branch } )
    
    return result as? XTLocalBranchItem
  }
  
  @objc(itemNamed:inGroup:)
  func item(named name: String, inGroup group: XTGroupIndex) -> XTSideBarItem?
  {
    let group = roots[group.rawValue]
    
    return group.children.first(where: { $0.title == name} )
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

// MARK: TeamCity
extension XTSideBarDataSource
{
  func updateTeamCity()
  {
    guard let repo = repo
    else { return }
    
    let localBranches = repo.localBranches()
    
    buildStatuses = [:]
    for local in localBranches {
      guard let fullBranchName = local.name,
            let tracked = local.trackingBranch,
            let (api, buildTypes) = matchTeamCity(tracked.remoteName)
      else { continue }
      
      for buildType in buildTypes {
        let vcsRoots = api.vcsRootsForBuildType(buildType)
        guard !vcsRoots.isEmpty
        else { continue }
        
        var shortestDisplayName: String? = nil
        
        for root in vcsRoots {
          guard let branchSpec = api.vcsBranchSpecs[root],
                let display = branchSpec.match(branch: fullBranchName)
          else { continue }
          
          if (shortestDisplayName == nil) ||
             (shortestDisplayName!.utf8.count > display.utf8.count) {
            shortestDisplayName = display
          }
        }
        
        guard let branchName = shortestDisplayName
        else { continue }
        
        let statusResource = api.buildStatus(branchName, buildType: buildType)
        
        statusResource.useData(owner: self) { (data) in
          guard let xml = data.content as? XMLDocument,
                let firstBuildElement =
                    xml.rootElement()?.children?.first as? XMLElement,
                let build = XTTeamCityAPI.Build(element: firstBuildElement)
          else { return }
          
          NSLog("\(buildType)/\(branchName): \(build.status)")
          var buildTypeStatuses = self.buildStatuses[buildType] ??
                                  [String: Bool]()
          
          buildTypeStatuses[branchName] = build.status == .succeeded
          self.buildStatuses[buildType] = buildTypeStatuses
          self.scheduleReload()
        }
      }
    }
  }
  
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
  
  /// Returns the first TeamCity service that builds from the given repository,
  /// and a list of its build types.
  func matchTeamCity(_ remoteName: String) -> (XTTeamCityAPI, [String])?
  {
    guard let repo = repo,
          let remote = XTRemote(name: remoteName, repository: repo),
          let remoteURL = remote.urlString
    else { return nil }
    
    let accounts = XTAccountsManager.manager.accounts(ofType: .teamCity)
    let services = accounts.flatMap({ XTServices.services.teamCityAPI($0) })
    
    for service in services {
      let buildTypes = service.buildTypesForRemote(remoteURL as String)
      
      if !buildTypes.isEmpty {
        return (service, buildTypes)
      }
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
    guard let remoteName = remoteName(forBranchItem: item),
          let (_, buildTypes) = matchTeamCity(remoteName)
    else { return nil }
    
    if (item is XTRemoteBranchItem) &&
       !branchHasLocalTrackingBranch(item.title) {
      return nil
    }
    
    let branchName = (item.title as NSString).lastPathComponent
    var overallSuccess: Bool?
    
    for buildType in buildTypes {
      if let status = buildStatuses[buildType],
         let buildSuccess = status[branchName] {
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
    return (item as! XTSideBarItem).children[index]
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
      dataView.statusImage.image = nil
      if let image = statusImage(for: sideBarItem) {
        dataView.statusImage.image = image
      }
      if sideBarItem is XTLocalBranchItem {
        if let statusText = graphText(for: sideBarItem) {
          dataView.statusText.title = statusText
          dataView.statusText.isHidden = false
        }
        else if dataView.statusImage.image == nil &&
                localBranchHasTrackingBranch(sideBarItem.title) {
          dataView.statusImage.image = NSImage(named: "cloudTemplate")
        }
      }
      dataView.statusImage.isHidden = dataView.statusImage.image == nil
      if sideBarItem.editable {
        textField.formatter = refFormatter
        textField.target = viewController
        textField.action =
            #selector(XTSidebarController.sidebarItemRenamed(_:))
      }
      if sideBarItem.current {
        textField.font = NSFont.boldSystemFont(
            ofSize: textField.font?.pointSize ?? 12)
      }
      else {
        textField.font = NSFont.systemFont(
            ofSize: textField.font?.pointSize ?? 12)
      }
      if sideBarItem is XTStagingItem {
        let changes = sideBarItem.model!.changes
        var stagedCount = 0, unstagedCount = 0
        
        for change in changes {
          if change.change != .unmodified {
            stagedCount += 1
          }
          if change.unstagedChange != .unmodified {
            unstagedCount += 1
          }
        }
        
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
