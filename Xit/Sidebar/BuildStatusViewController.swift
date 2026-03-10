import Cocoa
import XitGit

final class BuildStatusViewController: NSViewController
{
  typealias Repository = RemoteManagement & Branching
  
  weak var repository: (any Repository)!
  let branch: any Branch
  let buildStatusCache: BuildStatusCache
  var api: (any BuildStatusDisplayService)?
  @IBOutlet weak var tableView: NSTableView!
  @IBOutlet weak var headingLabel: NSTextField!
  @IBOutlet weak var refreshButton: NSButton!
  @IBOutlet weak var refreshSpinner: NSProgressIndicator!
  
  var filteredStatuses: [String: BuildStatusCache.BranchStatuses] = [:]
  var builds: [TeamCity.Build] = []
  
  enum CellID
  {
    static let build = ¶"BuildCell"
  }
  
  init(repository: any Repository, branch: any Branch, cache: BuildStatusCache)
  {
    self.repository = repository
    self.branch = branch
    self.buildStatusCache = cache
    
    super.init(nibName: .buildStatusNib, bundle: nil)
    
    cache.add(client: self)
    if let remoteName = branch.remoteName,
       let api = matchBuildStatusService(remoteName) {
      self.api = api
    }
    cache.add(client: self)
    filterStatuses()
  }
  
  required init?(coder: NSCoder)
  {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad()
  {
    super.viewDidLoad()
    headingLabel.uiStringValue = .buildStatus(branch.referenceName.localName)
  }
  
  override func viewWillDisappear()
  {
    buildStatusCache.remove(client: self)
  }
  
  func filterStatuses()
  {
    filteredStatuses.removeAll()
    
    // Only the local "refs/heads/..." version of the branch name works
    // with the branchspec matching.
    guard let api = self.api
    else {
      serviceLogger.debug("Build status popover has no display service for branch \(self.branch.referenceName.description, privacy: .public)")
      return
    }
    
    let branchName = branch.localRefName.fullPath
    serviceLogger.debug("Build status popover filtering cached statuses for branch \(branchName, privacy: .public); cached build types: \(self.buildStatusCache.statuses.keys.sorted(), privacy: .public)")
    
    for (buildType, branchStatuses) in buildStatusCache.statuses {
      let roots = api.cachedVCSRoots(for: buildType)
      guard !roots.isEmpty
      else {
        serviceLogger.debug("Build status popover found no cached VCS roots for build type \(buildType, privacy: .public)")
        continue
      }
      
      let matchNames = roots.compactMap {
        rootID -> String? in
        let match = api.cachedBranchSpec(for: rootID)?.match(branch: branchName)
        serviceLogger.debug("Build status popover branch spec match for build type \(buildType, privacy: .public) root \(rootID, privacy: .public): \(match ?? "nil", privacy: .public)")
        return match
      }
      guard let match = matchNames.reduce(nil, {
        (shortest, name) -> String? in
        (shortest.map { $0.count < name.count } ?? false) ? shortest : name
      })
      else {
        serviceLogger.debug("Build status popover found no matching branch spec for build type \(buildType, privacy: .public) branch \(branchName, privacy: .public)")
        continue
      }
      
      if let status = branchStatuses[match] {
        filteredStatuses[buildType] = [match: status]
        serviceLogger.debug("Build status popover kept cached status for build type \(buildType, privacy: .public) branch \(match, privacy: .public)")
      }
      else {
        serviceLogger.debug("Build status popover found no cached status entry for build type \(buildType, privacy: .public) branch \(match, privacy: .public); cached branches: \(branchStatuses.keys.sorted(), privacy: .public)")
      }
    }
    
    var buildsByNumber: [String: TeamCity.Build] = [:]
    
    for branchStatus in filteredStatuses.values {
      for status in branchStatus.values {
        buildsByNumber[status.number] = status
      }
    }
    builds = Array(buildsByNumber.values)
    serviceLogger.debug("Build status popover prepared \(self.builds.count) build rows for branch \(branchName, privacy: .public)")
  }
  
  func setProgressVisible(_ visible: Bool)
  {
    if visible {
      refreshSpinner.usesThreadedAnimation = true
      refreshSpinner.startAnimation(nil)
    }
    else {
      refreshSpinner.stopAnimation(nil)
    }
    refreshButton.isHidden = visible
    refreshSpinner.isHidden = !visible
    view.needsUpdateConstraints = true
  }
  
  @IBAction
  func refresh(_ sender: Any)
  {
    if let localBranch = repository.localBranch(for: branch),
       let remoteName = branch.remoteName {
      setProgressVisible(true)
      Task {
        do {
          try await buildStatusCache.refresh(remoteName: remoteName,
                                             branch: localBranch.referenceName)
        }
        catch {
          self.setProgressVisible(false)
        }
      }
    }
  }
  
  @IBAction
  func doubleClick(_ sender: Any)
  {
    let clickedRow = tableView.clickedRow
    guard 0..<builds.count ~= clickedRow
    else { return }
    let build = builds[tableView.clickedRow]
    guard let url = build.url
    else { return }
    
    NSWorkspace.shared.open(url)
  }
}

extension BuildStatusViewController: BuildStatusAccessor
{
  var servicesMgr: Services { Services.xit }
  var remoteMgr: (any RemoteManagement)! { repository }
}

extension BuildStatusViewController: BuildStatusClient
{
  nonisolated func buildStatusUpdated(branch: String, buildType: String)
  {
    DispatchQueue.main.async {
      [self] in
      filterStatuses()
      setProgressVisible(false)
      tableView.reloadData()
    }
  }
}

extension BuildStatusViewController: NSTableViewDelegate
{
  enum ColumnID
  {
    static let buildID = "buildID"
    static let status = "status"
  }
  
  func tableView(_ tableView: NSTableView,
                 viewFor tableColumn: NSTableColumn?,
                 row: Int) -> NSView?
  {
    guard let cell = tableView.makeView(withIdentifier: CellID.build,
                                        owner: self)
                     as? BuildStatusCellView
    else { return nil }
    let build = builds[row]
    let buildType = build.buildType.flatMap { id in api?.cachedBuildTypesSnapshot().first { $0.id == id } }
    
    cell.textField?.stringValue = buildType?.name ?? "-"
    cell.projectNameField.stringValue = buildType?.projectName ?? "-"
    cell.buildNumberField.stringValue = build.number
    if let percentage = build.percentage {
      cell.progressBar.isHidden = false
      cell.progressBar.doubleValue = percentage
    }
    else {
      cell.progressBar.isHidden = true
    }
    
    let state: BuildStatusController.DisplayState = build.status == .succeeded
        ? .success : .failure
    
    cell.statusImage.image = state.image
    cell.statusImage.contentTintColor = state.tint
    
    return cell
  }
}

extension BuildStatusViewController: NSTableViewDataSource
{
  func numberOfRows(in tableView: NSTableView) -> Int
  {
    return builds.count
  }
}
