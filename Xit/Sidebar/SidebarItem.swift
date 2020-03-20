import Cocoa

/// Represents all items in the sidebar
class SidebarItem: NSObject
{
  var title: String
  var children: [SidebarItem]
  var selection: RepositorySelection?
  
  var displayTitle: UIString { return UIString(rawValue: title) }
  var icon: NSImage? { return nil }
  var refType: RefType { return .unknown }
  var expandable: Bool { return false }
  // NSObject.isSelectable is new in 10.12
  override var isSelectable: Bool { return true }
  var editable: Bool { return false }
  var current: Bool { return false }
  
  required init(title: String)
  {
    self.title = title
    self.children = []
    
    super.init()
  }
  
  convenience init(title: String, selection: RepositorySelection)
  {
    self.init(title: title)
    self.selection = selection
  }
  
  /// Returns a copy of `self` with no children.
  func shallowCopy() -> Self
  {
    let copy = type(of: self).init(title: title)
    
    copy.selection = selection
    return copy
  }
  
  /// Returns a copy of `self` with copies of all children.
  func deepCopy() -> SidebarItem
  {
    let copy = shallowCopy()
    
    copy.children = children.map { $0.deepCopy() }
    return copy
  }
  
  func child(matching title: String) -> SidebarItem?
  {
    if let child = children.first(where: { $0.title == title }) {
      return child
    }
    if let child = children.firstResult({ $0.child(matching: title) }) {
      return child
    }
    return nil
  }
  
  func child(atPath path: String) -> SidebarItem?
  {
    let components = path.components(separatedBy: "/")
    guard let firstName = components.first,
          let child = child(matching: firstName)
    else { return nil }
    
    if components.count == 1 {
      return child
    }
    else {
      return child.child(atPath: components.dropFirst().joined(separator: "/"))
    }
  }
  
  /// Returns the first match in the hierarchy of child items
  func findChild(_ predicate: (SidebarItem) -> Bool) -> SidebarItem?
  {
    if predicate(self) {
      return self
    }
    else {
      return children.firstResult { $0.findChild(predicate) }
    }
  }
  
  override var description: String { return self.title }
  
  override func isEqual(_ object: Any?) -> Bool
  {
    guard let otherItem = object as? SidebarItem
    else { return false }
    
    return displayTitle == otherItem.displayTitle
  }
}

extension SidebarItem
{
  override var debugDescription: String { return displayTitle.rawValue }

  func printTree(_ depth: Int = 0)
  {
    let prefix = String(repeating: "  ", count: depth)
    
    print("\(prefix)\(debugDescription)")
    for child in children {
      child.printTree(depth + 1)
    }
  }
}


class SideBarGroupItem: SidebarItem
{
  init(titleString: UIString)
  {
    super.init(title: titleString.rawValue)
  }
  
  required init(title: String) { super.init(title: title) }
  
  override var isSelectable: Bool { return false }
  override var expandable: Bool { return true }
  
  override func isEqual(_ object: Any?) -> Bool
  {
    return object is SideBarGroupItem && super.isEqual(object)
  }
}


class StagingSidebarItem: SidebarItem
{
  init(titleString: UIString)
  {
    super.init(title: titleString.rawValue)
  }
  
  required init(title: String) { super.init(title: title) }

  override var icon: NSImage?
  {
    return NSImage(named: .xtStagingTemplate)
  }
}


class StashSidebarItem: SidebarItem
{
  override var icon: NSImage?
  {
    return NSImage(named: .xtStashTemplate)
  }
}


/// A sidebar item that has a ref name
protocol RefSidebarItem: SidebarItem
{
  var refName: String { get }
}


/// Abstract class for local and remote branch items
class BranchSidebarItem: SidebarItem
{
  override var displayTitle: UIString
  { return UIString(rawValue: (title as NSString).lastPathComponent) }
  override var icon: NSImage?
  { return NSImage(named: .xtBranchTemplate) }
  
  var fullName: String { return title }
  var remote: Remote? { return nil }
  
  func branchObject() -> Branch? { return nil }
}


class LocalBranchSidebarItem: BranchSidebarItem
{
  override var refType: RefType { return current ? .activeBranch : .branch }
  override var current: Bool
  {
    if let currentBranch = selection!.repository.currentBranch {
      return currentBranch == title
    }
    return false
  }
  

  override func branchObject() -> Branch?
  {
    return selection!.repository.localBranch(named: title)
  }
  
  override var remote: Remote?
  {
    guard let localBranch = branchObject() as? LocalBranch,
          let remoteBranch = localBranch.trackingBranch,
          let repo = selection!.repository as? RemoteManagement
    else { return nil }
    
    return remoteBranch.remoteName.flatMap { repo.remote(named: $0) }
  }

  func hasTrackingBranch() -> Bool
  {
    let branch = selection!.repository.localBranch(named: title)
    
    return branch?.trackingBranchName != nil
  }
}

extension LocalBranchSidebarItem: RefSidebarItem
{
  var refName: String
  { return RefPrefixes.heads.appending(pathComponent: title) }
}


class RemoteBranchSidebarItem: BranchSidebarItem
{
  var remoteName: String
  override var remote: Remote?
  {
    return (selection!.repository as? RemoteManagement)?.remote(named: remoteName)
  }
  override var refType: RefType { return .remoteBranch }
  
  override var fullName: String { return "\(remoteName)/\(title)" }
  

  required init(title: String, remote: String, selection: RepositorySelection?)
  {
    self.remoteName = remote
    
    super.init(title: title)
    self.selection = selection
  }
  
  required init(title: String)
  {
    self.remoteName = ""
    super.init(title: title)
  }

  override func shallowCopy() -> Self
  {
    return type(of: self).init(title: title, remote: remoteName,
                               selection: selection)
  }
  
  override func branchObject() -> Branch?
  {
    return selection!.repository.remoteBranch(named: title, remote: remoteName)
  }
}

extension RemoteBranchSidebarItem: RefSidebarItem
{
  var refName: String
  { return RefPrefixes.remotes.appending(pathComponent: fullName) }
}


class BranchFolderSidebarItem: SidebarItem
{
  override var icon: NSImage? { return NSImage(named: .xtFolderTemplate) }
  override var isSelectable: Bool { return false }
  override var expandable: Bool { return true }
}


class RemoteSidebarItem: SidebarItem
{
  let remote: Remote?
  
  override var icon: NSImage?
  {
    if let urlString = remote?.urlString,
       let url = URL(string: urlString),
       let host = url.host?.lowercased() {
      let hostsWithIcons: [(String, NSImage.Name)] =
            [("github.com", .xtGitHubTemplate),
             ("gitlab.com", .xtGitLabTemplate),
             ("bitbucket.com", .xtBitBucketTemplate)]

      for (domain, image) in hostsWithIcons {
        if (host == domain) || host.hasSuffix("." + domain) {
          return NSImage(named: image)
        }
      }
    }
    return NSImage(named: .xtCloudTemplate)
  }
  
  override var expandable: Bool { return true }
  override var editable: Bool { return true }
  override var refType: RefType { return .remote }
  
  init(title: String, repository: RemoteManagement)
  {
    self.remote = repository.remote(named: title)
    
    super.init(title: title)
  }
  
  required init(title: String, remote: Remote?)
  {
    self.remote = remote
    
    super.init(title: title)
  }
  
  required init(title: String)
  {
    self.remote = nil
    super.init(title: title)
  }
  
  override func shallowCopy() -> Self
  {
    return type(of: self).init(title: title, remote: remote)
  }
}


class TagSidebarItem: SidebarItem
{
  let tag: Tag

  override var displayTitle: UIString
  { return UIString(rawValue: (title as NSString).lastPathComponent) }
  override var icon: NSImage?
  { return NSImage(named: .xtTagTemplate) }
  override var refType: RefType { return .tag }

  required init(tag: Tag)
  {
    self.tag = tag
    
    super.init(title: tag.name)
    
    // The cast to GitTag is unfortunate but hard to get around. It doesn't seem
    // to make sense to have a repository property in the Tag protocol.
    if let commit = tag.commit,
       let xtTag = tag as? GitTag {
      self.selection = CommitSelection(repository: xtTag.repository,
                                       commit: commit)
    }
  }
  
  override func shallowCopy() -> Self
  {
    return type(of: self).init(tag: tag)
  }
  
  // Not used, but required
  required init(title: String)
  {
    self.tag = MockTag()
    super.init(title: title)
  }

  private struct MockTag: Tag
  {
    let name = ""
    let targetOID: OID? = nil
    let commit: Commit? = nil
    let message: String? = nil
  }
}

extension TagSidebarItem: RefSidebarItem
{
  var refName: String
  { return RefPrefixes.tags.appending(pathComponent: title) }
}


class SubmoduleSidebarItem: SidebarItem
{
  let submodule: Submodule
  override var icon: NSImage?
  { return NSImage(named: .xtSubmoduleTemplate) }
  
  required init(submodule: Submodule)
  {
    self.submodule = submodule
    
    super.init(title: submodule.name)
  }
  
  override func shallowCopy() -> Self
  {
    return type(of: self).init(submodule: submodule)
  }
  
  required init(title: String)
  {
    self.submodule = MockSubmodule()
    super.init(title: title)
  }
  
  private class MockSubmodule: Submodule
  {
    let name = ""
    let path = ""
    let url: URL? = nil
    
    var ignoreRule: SubmoduleIgnore = .none
    var updateStrategy: SubmoduleUpdate = .none
    var recurse: SubmoduleRecurse = .no
  }
}
