import Cocoa

final class BuildStatusViewController: NSViewController
{
  typealias Repository = RemoteManagement & Branching

  weak var repository: (any Repository)!
  let branch: any Branch
  let buildStatusCache: BuildStatusCache
  var api: BuildStatusService?
  @IBOutlet weak var tableView: NSTableView!
  @IBOutlet weak var headingLabel: NSTextField!
  @IBOutlet weak var refreshButton: NSButton!
  @IBOutlet weak var refreshSpinner: NSProgressIndicator!

  var filteredStatuses: [String: BuildStatusCache.BranchStatuses] = [:]
  var builds: [TeamCityAPI.Build] = []
  
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
       let (api, _) = matchBuildStatusService(remoteName) {
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
    headingLabel.uiStringValue = .buildStatus(branch.strippedName)
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
    else { return }
    
    let branchName = (branch is (any RemoteBranch))
          ? RefPrefixes.heads + branch.strippedName
          : branch.name
    
    for (buildType, branchStatuses) in buildStatusCache.statuses {
      let roots = api.vcsRootsForBuildType(buildType)
      guard !roots.isEmpty
      else { continue }
      
      let matchNames = roots.compactMap
          { api.vcsBranchSpecs[$0]?.match(branch: branchName) }
      guard let match = matchNames.reduce(nil, {
        (shortest, name) -> String? in
        (shortest.map { $0.count < name.count } ?? false) ? shortest : name
      })
      else { continue }
      
      if let status = branchStatuses[match] {
        filteredStatuses[buildType] = [match: status]
      }
    }
    
    var buildsByNumber: [String: TeamCityAPI.Build] = [:]
    
    for branchStatus in filteredStatuses.values {
      for status in branchStatus.values {
        buildsByNumber[status.number] = status
      }
    }
    builds = Array(buildsByNumber.values)
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
    if let localBranch = branch as? (any LocalBranch) ??
                         (branch as? (any RemoteBranch)).flatMap({
                            repository.localBranch(tracking: $0) }),
       let remoteName = branch.remoteName {
      setProgressVisible(true)
      Task {
        do {
          try await buildStatusCache.refresh(remoteName: remoteName,
                                             branchName: localBranch.name)
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
  func buildStatusUpdated(branch: String, buildType: String)
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
    let buildType = build.buildType.flatMap { api?.buildType(id: $0) }
    
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
    cell.statusImage.image = NSImage(named:
        build.status == .succeeded ? NSImage.Name.xtBuildSucceeded
                                   : NSImage.Name.xtBuildFailed)
    
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
