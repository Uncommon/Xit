import Foundation
import Combine
import Cocoa

@MainActor
protocol BuildStatusDisplay: AnyObject
{
  func updateStatusImage(item: SidebarItem)
}

@MainActor
final class BuildStatusController: NSObject
{
  // The TeamCity server data has succeeded/failed and running/finished as
  // separate states, but we combine them for display
  enum DisplayState: CaseIterable
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
      switch build {
        case _ where build.status == .failed:
          self = .failure
        case _ where build.state == .running:
          self = .running
        default:
          self = .success
      }
    }
    
    static func += (left: inout DisplayState, right: DisplayState)
    {
      switch (left, right) {
        case (_, .failure):
          left = .failure
        case (.unknown, .running), (.success, .running):
          left = .running
        case (.unknown, .success):
          left = .success
        default:
          break
      }
    }
  }
  
  let refreshInterval: TimeInterval = 5 * .minutes
  
  let model: SidebarDataModel
  let buildStatusCache: BuildStatusCache
  var statusSink: AnyCancellable?
  var popover: NSPopover?
  weak var display: (any BuildStatusDisplay)?
  var refreshTimer: Timer! = nil

  init(model: SidebarDataModel, display: any BuildStatusDisplay)
  {
    self.model = model
    self.display = display
    self.buildStatusCache = BuildStatusCache(branchLister: model.repository!,
                                             remoteMgr: model.repository!)
    
    super.init()
    
    buildStatusCache.add(client: self)
    if let api: TeamCityAPI = Services.xit.allServices.firstOfType() {
      statusSink = api.$buildTypesStatus.sink {
        [weak self] _ in
        self?.buildStatusCache.refresh()
      }
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
          let refString = (branchItem as? RefSidebarItem)?.refName,
          let remoteName = RemoteBranchRefName(rawValue: refString),
          let localBranch = branchItem.branchObject() as? any LocalBranch ??
                            model.repository?
                                 .localTrackingBranch(forBranch: remoteName)
    else { return nil }

    guard let remoteName = model.remoteName(forBranchItem: item),
          let (api, buildTypes) = matchBuildStatusService(remoteName)
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
    DispatchQueue.main.async {
      [self] in
      Signpost.interval(.buildStatusUpdate(buildType)) {
        updateBranches(model.rootItem(.branches).children)
        for remoteItem in model.rootItem(.remotes).children {
          updateBranches(remoteItem.children)
        }
      }
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

extension BuildStatusController: BuildStatusAccessor
{
  var servicesMgr: Services { Services.xit }
  var remoteMgr: (any RemoteManagement)! { model.repository }
}
