import Foundation
import Combine
import Cocoa
import XitGit
import os

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
        case .unknown: "circle"
        case .success: "checkmark.circle.fill"
        case .running: "clock.fill"
        case .failure: "xmark.circle.fill"
      }
    }
    
    var tint: NSColor
    {
      switch self {
        case .unknown: .labelColor
        case .success: .systemGreen
        case .running: .systemBlue
        case .failure: .systemRed
      }
    }
    
    var image: NSImage {
      .init(systemSymbolName: imageName)!
    }
    
    init(build: TeamCity.Build)
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
    if let api = Services.xit.teamCityServiceList.first {
      serviceLogger.debug("Build status controller subscribing to TeamCity service at \(api.account.location.absoluteString, privacy: .public)")
      statusSink = api.$buildTypesStatus.sink {
        [weak self] status in
        serviceLogger.debug("Build status controller observed TeamCity metadata status change: \(String(describing: status), privacy: .public)")
        guard case .done = status else { return }
        self?.buildStatusCache.refresh()
      }
    }
    else {
      serviceLogger.debug("Build status controller found no TeamCity service to subscribe to")
    }
    refreshTimer = .mainScheduledTimer(withTimeInterval: refreshInterval,
                                       repeats: true) {
      [weak self] _ in
      serviceLogger.debug("Build status controller periodic refresh fired")
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
  
  // NSImage doesn't seem to have a good way to apply tint color, so the caller
  // will apply it on the image view or button.
  func statusImage(for item: SidebarItem) async -> (NSImage, NSColor)?
  {
    guard let branchItem = item as? BranchSidebarItem
    else {
      serviceLogger.debug("Status image requested for non-branch item \(item.title, privacy: .public)")
      return nil
    }
    
    let localBranchRef: LocalBranchRefName
    switch branchItem {
      case let localItem as LocalBranchSidebarItem:
        guard let branch = localItem.branchObject() as? any LocalBranch
        else {
          serviceLogger.debug("Failed to resolve local branch object for sidebar item \(item.title, privacy: .public)")
          return nil
        }
        localBranchRef = branch.referenceName
        serviceLogger.debug("Resolving status image for local branch item \(item.title, privacy: .public) as \(localBranchRef.fullPath, privacy: .public)")
      case let remoteItem as RemoteBranchSidebarItem:
        guard let remoteRef = RemoteBranchRefName(rawValue: remoteItem.refName),
              let branch = model.repository?.localTrackingBranch(forBranch: remoteRef)
        else {
          serviceLogger.debug("Failed to resolve tracking local branch for remote sidebar item \(item.title, privacy: .public) ref \(remoteItem.refName, privacy: .public)")
          return nil
        }
        localBranchRef = branch.referenceName
        serviceLogger.debug("Resolving status image for remote branch item \(item.title, privacy: .public) via local branch \(localBranchRef.fullPath, privacy: .public)")
      default:
        serviceLogger.debug("Unsupported branch item type for status image: \(String(describing: type(of: branchItem)), privacy: .public)")
        return nil
    }
    
    guard let remoteName = model.remoteName(forBranchItem: item)
    else {
      serviceLogger.debug("No remote name for sidebar item \(item.title, privacy: .public)")
      return nil
    }
    guard let (api, buildTypes) = await matchBuildStatusServiceAndTypes(remoteName)
    else {
      serviceLogger.debug("No TeamCity service/build types matched remote \(remoteName, privacy: .public) for item \(item.title, privacy: .public)")
      return nil
    }
    serviceLogger.debug("Matched TeamCity service \(api.account.location.absoluteString, privacy: .public) with \(buildTypes.count) build types for item \(item.title, privacy: .public)")
    
    var overallState = DisplayState.unknown
    
    for buildType in buildTypes {
      let branchName = await api.displayName(for: localBranchRef,
                                             buildType: buildType)
      serviceLogger.debug("TeamCity display name for branch \(localBranchRef.fullPath, privacy: .public) build type \(buildType, privacy: .public): \(branchName ?? "nil", privacy: .public)")
      guard let branchName,
            let status = buildStatusCache.statuses[buildType],
            let branchStatus = status[branchName]
      else {
        serviceLogger.debug("No cached status for build type \(buildType, privacy: .public); cached branches: \(String(describing: self.buildStatusCache.statuses[buildType]?.keys.sorted()), privacy: .public)")
        continue
      }
      overallState += DisplayState(build: branchStatus)
      serviceLogger.debug("Resolved cached TeamCity status \(branchStatus.status?.rawValue ?? "?", privacy: .public) / \(branchStatus.state?.rawValue ?? "?", privacy: .public) for branch \(branchName, privacy: .public) build type \(buildType, privacy: .public)")
    }
    
    serviceLogger.debug("Returning sidebar status image \(overallState.imageName, privacy: .public) for item \(item.title, privacy: .public)")
    return (overallState.image, overallState.tint)
  }
}

extension BuildStatusController: BuildStatusClient
{
  nonisolated
  func buildStatusUpdated(branch: String, buildType: String)
  {
    DispatchQueue.main.async {
      [self] in
      serviceLogger.debug("Build status controller received cache update for branch \(branch, privacy: .public) build type \(buildType, privacy: .public)")
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
          if let display {
            serviceLogger.debug("Requesting sidebar display refresh for branch item \(item.title, privacy: .public)")
            Task {
              @MainActor in
              display.updateStatusImage(item: item)
            }
          }
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

extension BuildStatusController: @MainActor BuildStatusAccessor
{
  nonisolated var servicesMgr: Services { Services.xit }
  nonisolated var remoteMgr: (any RemoteManagement)! { model.repository }
}
