import Foundation

protocol BuildStatusDisplay: AnyObject
{
  func updateStatusImage(item: SidebarItem)
}

class BuildStatusController: NSObject
{
  // The TeamCity server data has succeeded/failed and running/finished as
  // separate states, but we combine them for display
  enum DisplayState
  {
    case unknown
    case success
    case running
    case failure
    
    var imageName: NSImage.Name
    {
      switch self {
        case .unknown:
          return .xtNoBuilds
        case .success:
          return .xtBuildSucceeded
        case .running:
          return .xtBuildInProgress
        case .failure:
          return .xtBuildFailed
      }
    }
    
    init(build: TeamCityAPI.Build)
    {
      if build.status == .failed {
        self = .failure
      }
      else if build.state == .running {
        self = .running
      }
      else {
        self = .success
      }
    }
    
    static func += (left: inout DisplayState, right: DisplayState)
    {
      switch right {
        case .failure:
          left = .failure
        case .running:
          if left != .failure {
            left = .running
          }
        case .success, .unknown:
          left = right
      }
    }
  }
  
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
    
    buildStatusCache.add(client: self)
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
    
    var overallState = DisplayState.unknown
    
    for buildType in buildTypes {
      if let branchName = api.displayName(forBranch: localBranch.name,
                                          buildType: buildType),
         let status = buildStatusCache.statuses[buildType],
         let branchStatus = status[branchName] {
        overallState += DisplayState(build: branchStatus)
      }
    }
    
    return NSImage(named: overallState.imageName)
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
}
