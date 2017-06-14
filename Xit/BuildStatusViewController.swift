import Cocoa

class BuildStatusViewController: NSViewController, TeamCityAccessor
{
  let repository: XTRepository
  let branch: XTBranch
  let buildStatusCache: BuildStatusCache
  @IBOutlet weak var tableView: NSTableView!

  var filteredStatuses: [String: BuildStatusCache.BranchStatuses] = [:]
  var builds: [TeamCityAPI.Build] = []

  init(repository: XTRepository, branch: XTBranch, cache: BuildStatusCache)
  {
    self.repository = repository
    self.branch = branch
    self.buildStatusCache = cache
  
    super.init(nibName: "BuildStatusViewController", bundle: nil)!
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
          let remoteName = branch.remoteName,
          let (api, _) = matchTeamCity(remoteName)
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
      
      if branchStatuses.keys.contains(match) {
        filteredStatuses[buildType] = branchStatuses
      }
    }
    
    var buildsByID: [String: TeamCityAPI.Build] = [:]
    
    for branchStatus in filteredStatuses.values {
      for status in branchStatus.values {
        guard let id = status.id
        else { continue }
      
        buildsByID[id] = status
      }
    }
    builds = Array(buildsByID.values)
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
    guard let column = tableColumn,
          let cell = tableView.make(withIdentifier: column.identifier,
                                    owner: self) as? NSTableCellView
    else { return nil }
    let build = builds[row]
    
    switch column.identifier {
      case ColumnID.buildID:
        cell.textField?.stringValue = build.id ?? ""
      case ColumnID.status:
        cell.textField?.stringValue =
            "\(build.state?.rawValue ?? "-") / \(build.status?.rawValue ?? "-")"
      default:
        return nil
    }
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
