import Cocoa

class BuildStatusViewController: NSViewController, TeamCityAccessor
{
  let repository: XTRepository
  let branch: XTBranch
  let buildStatusCache: BuildStatusCache
  var api: TeamCityAPI?
  @IBOutlet weak var tableView: NSTableView!

  var filteredStatuses: [String: BuildStatusCache.BranchStatuses] = [:]
  var builds: [TeamCityAPI.Build] = []

  init(repository: XTRepository, branch: XTBranch, cache: BuildStatusCache)
  {
    self.repository = repository
    self.branch = branch
    self.buildStatusCache = cache
  
    super.init(nibName: "BuildStatusViewController", bundle: nil)!
    
    if let remoteName = branch.remoteName,
       let (api, _) = matchTeamCity(remoteName) {
      self.api = api
    }
    cache.add(client: self)
    filterStatuses()
  }
  
  required init?(coder: NSCoder)
  {
    fatalError("init(coder:) has not been implemented")
  }
  
  deinit
  {
    buildStatusCache.remove(client: self)
  }

  func filterStatuses()
  {
    filteredStatuses.removeAll()
    
    guard let branchName = branch.name,
          let api = self.api
    else { return }
    
    for (buildType, branchStatuses) in buildStatusCache.statuses {
      let roots = api.vcsRootsForBuildType(buildType)
      guard !roots.isEmpty
      else { continue }
      
      let matchNames = roots.flatMap
          { api.vcsBranchSpecs[$0]?.match(branch: branchName) }
      guard let match = matchNames.reduce(nil, {
        (shortest, name) -> String? in
        return (shortest.map { $0.characters.count < name.characters.count }
                ?? false)
               ? shortest : name
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
}

extension BuildStatusViewController: BuildStatusClient
{
  func buildStatusUpdated(branch: String, buildType: String)
  {
    filterStatuses()
    tableView.reloadData()
  }
}

extension BuildStatusViewController: NSTableViewDelegate
{
  struct ColumnID
  {
    static let buildID = "buildID"
    static let status = "status"
  }

  func tableView(_ tableView: NSTableView,
                 viewFor tableColumn: NSTableColumn?,
                 row: Int) -> NSView?
  {
    guard let cell = tableView.make(withIdentifier: "BuildCell", owner: self)
                     as? BuildStatusCellView
    else { return nil }
    let build = builds[row]
    let buildType = build.buildType.flatMap { api?.buildType(id: $0) }
    
    cell.textField?.stringValue = build.buildType ?? "-"
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
        build.status == .succeeded ? NSImageNameStatusAvailable
                                   : NSImageNameStatusUnavailable)
    
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
