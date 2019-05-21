import Foundation

protocol BuildStatusDisplay: AnyObject
{
  func updateStatusImage(item: SidebarItem)
}

class BuildStatusController: NSObject
{
  let refreshInterval: TimeInterval = 5 * .minutes
  
  let model: SidebarDataModel
  let buildStatusCache: BuildStatusCache
  var statusObserver: NSObjectProtocol! = nil
  var popover: NSPopover?
  weak var display: BuildStatusDisplay?
  var refreshTimer: Timer! = nil

  init(model: SidebarDataModel, display: BuildStatusDisplay)
  {
    self.model = model
    self.display = display
    self.buildStatusCache = BuildStatusCache(branchLister: model.repository!,
                                             remoteMgr: model.repository!)
    
    super.init()
    
    statusObserver = NotificationCenter.default.addObserver(
        forName: .XTTeamCityStatusChanged, object: nil, queue: .main) {
      [weak self] _ in
      self?.buildStatusCache.refresh()
    }
    refreshTimer = .scheduledTimer(withTimeInterval: refreshInterval,
                                   repeats: true) {
      [weak self] _ in
      self?.buildStatusCache.refresh()
    }
  }
  
  deinit
  {
    refreshTimer?.invalidate()
    statusObserver.map { NotificationCenter.default.removeObserver($0) }
  }
  
  @IBAction
  func showItemStatus(_ sender: NSButton)
  {
    guard let item = SidebarTableCellView.item(for: sender) as? BranchSidebarItem,
          let branch = item.branchObject()
    else { return }
    
    let statusController = BuildStatusViewController(
          repository: model.repository!,
          branch: branch,
          cache: buildStatusCache)
    let popover = NSPopover()
    
    self.popover = popover
    popover.contentViewController = statusController
    popover.behavior = .transient
    popover.delegate = self
    popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .maxY)
  }
}

extension BuildStatusController: BuildStatusClient
{
  func buildStatusUpdated(branch: String, buildType: String)
  {
    updateBranches(model.rootItem(.branches).children)
    for remoteItem in model.rootItem(.remotes).children {
      updateBranches(remoteItem.children)
    }
  }
  
  private func updateBranches(_ branchItems: [SidebarItem])
  {
    for item in branchItems {
      switch item {
      case is BranchSidebarItem:
        display?.updateStatusImage(item: item)
      case is BranchFolderSidebarItem:
        updateBranches(item.children)
      default:
        break
      }
    }
  }
}

extension BuildStatusController: NSPopoverDelegate
{
  func popoverDidClose(_ notification: Notification)
  {
    popover = nil
  }
}

extension BuildStatusController: TeamCityAccessor
{
  var remoteMgr: RemoteManagement! { return model.repository }
  
  func statusImage(for item: SidebarItem) -> NSImage?
  {
    guard let branchItem = item as? BranchSidebarItem,
          let refName = (branchItem as? RefSidebarItem)?.refName,
          let localBranch = branchItem.branchObject() as? LocalBranch ??
                            model.repository?
                                 .localTrackingBranch(forBranchRef: refName)
    else { return nil }

    guard let remoteName = model.remoteName(forBranchItem: item),
          let (api, buildTypes) = matchTeamCity(remoteName)
    else { return nil }
    
    var overallSuccess: Bool?
    
    for buildType in buildTypes {
      if let branchName = api.displayName(forBranch: localBranch.name,
                                          buildType: buildType),
         let status = buildStatusCache.statuses[buildType],
         let buildSuccess = status[branchName].map({ $0.status == .succeeded }) {
        overallSuccess = (overallSuccess ?? true) && buildSuccess
      }
    }
    
    if let success = overallSuccess {
      return NSImage(named: success ? NSImage.statusAvailableName
                                    : NSImage.statusUnavailableName)
    }
    else {
      return NSImage(named: NSImage.statusNoneName)
    }
  }
}
