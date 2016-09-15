import Cocoa


extension XTSideBarDataSource {
  
  @nonobjc static let kReloadInterval: TimeInterval = 1
  
  open override func awakeFromNib()
  {
    outline!.target = self
    outline!.doubleAction = #selector(XTSideBarDataSource.doubleClick(_:))
    if (!XTAccountsManager.manager.accounts(ofType: .teamCity).isEmpty) {
      buildStatusTimer = Timer.scheduledTimer(
          timeInterval: 60 * 5,
          target: self,
          selector: #selector(XTSideBarDataSource.buildStatusTimerFired(_:)),
          userInfo: nil, repeats: true)
    }
  }
  
  func stopTimers()
  {
    buildStatusTimer?.invalidate()
    reloadTimer?.invalidate()
  }
  
  func buildStatusTimerFired(_ timer: Timer)
  {
    updateTeamCity()
  }
  
  func scheduleReload()
  {
    if let timer = reloadTimer , timer.isValid {
      timer.fireDate =
          Date(timeIntervalSinceNow: XTSideBarDataSource.kReloadInterval)
    }
    else {
      reloadTimer = Timer.scheduledTimer(
          timeInterval: XTSideBarDataSource.kReloadInterval,
          target: self,
          selector: #selector(XTSideBarDataSource.reloadTimerFired(_:)),
          userInfo: nil,
          repeats: false)
    }
  }
  
  func reloadTimerFired(_ timer: Timer)
  {
    DispatchQueue.main.async { 
      self.outline!.reloadData()
    }
    reloadTimer = nil
  }
  
  func makeRoots() -> [XTSideBarGroupItem]
  {
    let rootNames =
        ["WORKSPACE", "BRANCHES", "REMOTES", "TAGS", "STASHES", "SUBMODULES"];
    let roots = rootNames.map({ XTSideBarGroupItem(title: $0) })
    
    roots[0].addChild(stagingItem)
    return roots;
  }
  
  func makeTagItems() -> [XTTagItem]
  {
    guard let tags = try? repo!.tags()
    else { return [XTTagItem]() }
    
    return tags.map({ XTTagItem(tag: $0)})
  }
  
  func makeStashItems() -> [XTStashItem]
  {
    let stashes = repo!.stashes()
    var stashItems = [XTStashItem]()
    
    for (index, stash) in stashes.enumerated() {
      let model = XTStashChanges(repository: repo!, stash: stash)
      let message = stash.message ?? "stash \(index)"
    
      stashItems.append(XTStashItem(title: message, model: model))
    }
    return stashItems
  }
  
  func makeSubmoduleItems() -> [XTSubmoduleItem]
  {
    return repo!.submodules().map({ XTSubmoduleItem(submodule: $0) })
  }
  
}

extension XTSideBarDataSource { // MARK: TeamCity
  
  func updateTeamCity()
  {
    guard let repo = repo,
          let localBranches = try? repo.localBranches()
    else { return }
    
    buildStatuses = [:]
    for local in localBranches {
      guard let fullBranchName = local.name,
            let tracked = local.trackingBranch,
            let (api, buildTypes) = matchTeamCity(tracked.remoteName)
      else { continue }
      
      let branchName = (fullBranchName as NSString).lastPathComponent
      
      for buildType in buildTypes {
        let statusResource = api.buildStatus(branchName, buildType: buildType)
        
        statusResource.useData(owner: self) { (data) in
          guard let xml = data.content as? XMLDocument,
                let firstBuildElement =
                    xml.rootElement()?.children?.first as? XMLElement,
                let build = XTTeamCityAPI.Build(element: firstBuildElement)
          else { return }
          
          NSLog("\(buildType)/\(branchName): \(build.status)")
          var buildTypeStatuses = self.buildStatuses[buildType] as? [String: Bool] ?? [String: Bool]()
          
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
  
  func statusImage(_ item: XTSideBarItem) -> NSImage?
  {
    guard let remoteName = remoteName(forBranchItem: item),
          let (_, buildTypes) = matchTeamCity(remoteName)
    else { return nil }
    
    let branchName = (item.title as NSString).lastPathComponent
    var overallSuccess: Bool?
    
    for buildType in buildTypes {
      if let status = buildStatuses[buildType] as? [NSString:NSNumber],
         let buildSuccess = status[branchName as NSString]?.boolValue {
        overallSuccess = (overallSuccess ?? true) && buildSuccess
      }
    }
    if overallSuccess == nil {
      return NSImage(named: NSImageNameStatusNone)
    }
    else {
      return NSImage(named: overallSuccess!
          ? NSImageNameStatusAvailable
          : NSImageNameStatusUnavailable)
    }
  }
}

extension XTSideBarDataSource: NSOutlineViewDataSource {
  // MARK: NSOutlineViewDataSource
  
  public func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
    if item == nil {
      return roots.count
    }
    return (item as? XTSideBarItem)?.children.count ?? 0
  }
  
  public func outlineView(_ outlineView: NSOutlineView,
                          isItemExpandable item: Any) -> Bool {
    return (item as? XTSideBarItem)?.expandable ?? false
  }
  
  public func outlineView(_ outlineView: NSOutlineView,
                          child index: Int,
                          ofItem item: Any?) -> Any {
    if item == nil {
      return roots[index]
    }
    return (item as! XTSideBarItem).children[index]
  }
}

extension XTSideBarDataSource: NSOutlineViewDelegate {
  // MARK: NSOutlineViewDelegate

  public func outlineViewSelectionDidChange(_ notification: Notification)
  {
    guard let item = outline!.item(atRow: outline!.selectedRow) as? XTSideBarItem,
          let model = item.model,
          let controller = outline!.window?.windowController as? XTWindowController
    else { return }
    
    controller.selectedModel = model
  }


  public func outlineView(_ outlineView: NSOutlineView,
                          isGroupItem item: Any) -> Bool
  {
    return item is XTSideBarGroupItem
  }

  public func outlineView(_ outlineView: NSOutlineView,
                          shouldSelectItem item: Any) -> Bool
  {
    return (item as? XTSideBarItem)?.selectable ?? false
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
          withIdentifier: "DataCell", owner: nil) as? XTSideBarTableCellView
      else { return nil }
      
      let textField = dataView.textField!
      
      dataView.item = sideBarItem
      dataView.imageView?.image = sideBarItem.icon
      textField.stringValue = sideBarItem.displayTitle
      textField.isEditable = sideBarItem.editable
      textField.isSelectable = sideBarItem.selectable
      dataView.statusImage.image = statusImage(sideBarItem)
      if sideBarItem.editable {
        textField.formatter = refFormatter
        textField.target = viewController
        textField.action =
            #selector(XTHistoryViewController.sideBarItemRenamed(_:))
      }
      if sideBarItem.current {
        textField.font = NSFont.boldSystemFont(
            ofSize: textField.font?.pointSize ?? 12)
      }
      else {
        textField.font = NSFont.systemFont(
            ofSize: textField.font?.pointSize ?? 12)
      }
      return dataView
    }
  }
}
