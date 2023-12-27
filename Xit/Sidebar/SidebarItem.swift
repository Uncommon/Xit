import Cocoa

/// Represents all items in the sidebar
class SidebarItem: NSObject
{
  var title: String
  var children: [SidebarItem]
  var selection: (any RepositorySelection)?
  
  var displayTitle: UIString { UIString(rawValue: title) }
  var icon: NSImage? { nil }
  var refType: RefType { .unknown }
  var isExpandable: Bool { false }
  // NSObject.isSelectable is new in 10.12
  override var isSelectable: Bool { true }
  var isEditable: Bool { false }
  var isCurrent: Bool { false }
  
  required init(title: String)
  {
    self.title = title
    self.children = []
    
    super.init()
  }
  
  convenience init(title: String, selection: any RepositorySelection)
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
  
  override var description: String { self.title }
  
  override func isEqual(_ object: Any?) -> Bool
  {
    guard let otherItem = object as? SidebarItem
    else { return false }
    
    return displayTitle == otherItem.displayTitle &&
           selection?.oidToSelect == otherItem.selection?.oidToSelect
  }
}

extension SidebarItem
{
  override var debugDescription: String { displayTitle.rawValue }

  func printTree(_ depth: Int = 0)
  {
    let prefix = String(repeating: "  ", count: depth)
    
    print("\(prefix)\(debugDescription)")
    for child in children {
      child.printTree(depth + 1)
    }
  }
}


final class SideBarGroupItem: SidebarItem
{
  init(titleString: UIString)
  {
    super.init(title: titleString.rawValue)
  }
  
  required init(title: String) { super.init(title: title) }
  
  override var isSelectable: Bool { false }
  override var isExpandable: Bool { true }
  
  override func isEqual(_ object: Any?) -> Bool
  {
    return object is SideBarGroupItem && super.isEqual(object)
  }
}


final class StagingSidebarItem: SidebarItem
{
  init(titleString: UIString)
  {
    super.init(title: titleString.rawValue)
  }
  
  required init(title: String) { super.init(title: title) }

  override var icon: NSImage?
  { .xtStaging }
}


final class StashSidebarItem: SidebarItem
{
  override var icon: NSImage?
  { .xtStash }
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
  { UIString(rawValue: (title as NSString).lastPathComponent) }
  override var icon: NSImage?
  { .xtBranch }
  
  var fullName: String { title }
  var remote: (any Remote)? { nil }
  
  func branchObject() -> (any Branch)?
  {
    return nil
  }
}


final class LocalBranchSidebarItem: BranchSidebarItem
{
  override var refType: RefType { isCurrent ? .activeBranch : .branch }
  override var isCurrent: Bool
  {
    if let currentBranch = selection!.repository.currentBranch {
      return currentBranch == title
    }
    return false
  }
  

  override func branchObject() -> (any Branch)?
  {
    guard let refName = LocalBranchRefName(title)
    else { return nil }
    
    return selection!.repository.localBranch(named: refName)
  }
  
  override var remote: (any Remote)?
  {
    guard let localBranch = branchObject() as? any LocalBranch,
          let remoteBranch = localBranch.trackingBranch,
          let repo = selection!.repository as? any RemoteManagement
    else { return nil }
    
    return remoteBranch.remoteName.flatMap { repo.remote(named: $0) }
  }

  func hasTrackingBranch() -> Bool
  {
    guard let refName = LocalBranchRefName(title),
          let branch = selection!.repository.localBranch(named: refName)
    else { return false }
    
    return branch.trackingBranchName != nil
  }
}

extension LocalBranchSidebarItem: RefSidebarItem
{
  var refName: String
  { RefPrefixes.heads.appending(pathComponent: title) }
}


final class RemoteBranchSidebarItem: BranchSidebarItem
{
  var remoteName: String
  override var remote: (any Remote)?
  { (selection!.repository as? any RemoteManagement)?.remote(named: remoteName) }
  override var refType: RefType { .remoteBranch }
  
  override var fullName: String { "\(remoteName)/\(title)" }
  

  required init(title: String,
                remote: String,
                selection: (any RepositorySelection)?)
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
  
  override func branchObject() -> (any Branch)?
  {
    return selection!.repository.remoteBranch(named: title, remote: remoteName)
  }
}

extension RemoteBranchSidebarItem: RefSidebarItem
{
  var refName: String
  { RefPrefixes.remotes.appending(pathComponent: fullName) }
}


final class BranchFolderSidebarItem: SidebarItem
{
  override var icon: NSImage? { .xtBranchFolder }
  override var isSelectable: Bool { false }
  override var isExpandable: Bool { true }
}


final class RemoteSidebarItem: SidebarItem
{
  let remote: (any Remote)?
  
  override var icon: NSImage?
  {
    if let urlString = remote?.urlString,
       let url = URL(string: urlString),
       let host = url.host?.lowercased() {
      let hostsWithIcons: [(String, NSImage.Name)] =
            [("github.com", .xtGitHub),
             ("gitlab.com", .xtGitLab),
             ("bitbucket.com", .xtBitBucketTemplate)]

      for (domain, image) in hostsWithIcons {
        if (host == domain) || host.hasSuffix("." + domain) {
          return NSImage(named: image)
        }
      }
    }
    return .xtRemote
  }
  
  override var isExpandable: Bool { true }
  override var isEditable: Bool { true }
  override var refType: RefType { .remote }
  
  init(title: String, repository: any RemoteManagement)
  {
    self.remote = repository.remote(named: title)
    
    super.init(title: title)
  }
  
  required init(title: String, remote: (any Remote)?)
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


final class TagSidebarItem: SidebarItem
{
  let tag: any Tag

  override var displayTitle: UIString
  { UIString(rawValue: (title as NSString).lastPathComponent) }
  override var icon: NSImage?
  {
    switch tag.type {
      case .lightweight:
        return .xtTagLight
      case .annotated:
        return tag.isSigned ? NSImage(systemSymbolName: "seal.fill")! : .xtTag
    }
  }
  override var refType: RefType { .tag }

  required init(tag: any Tag)
  {
    self.tag = tag
    
    super.init(title: tag.name)
    
    // The cast to GitTag is unfortunate but hard to get around. It doesn't seem
    // to make sense to have a repository property in the Tag protocol.
    if let commit = tag.commit as (any Commit)?,
       let xtTag = tag as? GitTag {
      self.selection = xtTag.repository.map {
        CommitSelection(repository: $0, commit: commit)
      }
    }
  }
  
  override func shallowCopy() -> Self
  {
    return type(of: self).init(tag: tag)
  }
  
  // Not used, but required
  required init(title: String)
  {
    assertionFailure("This initializer shouldn't be used.")
    self.tag = MockTag()
    super.init(title: title)
  }

  internal struct MockTag: Tag
  {
    let name = ""
    let signature: Signature? = .init(
      name: "Mock",
      email: "mock@example.com",
      when: .init())
    let targetOID: StringOID? = nil
    let commit: StringCommit? = nil
    let message: String? = nil
    let type: TagType = .annotated
    let isSigned: Bool = false
  }
}

extension TagSidebarItem: RefSidebarItem
{
  var refName: String
  { RefPrefixes.tags.appending(pathComponent: title) }
}


class SubmoduleSidebarItem: SidebarItem
{
  let submodule: any Submodule
  override var icon: NSImage?
  { .xtSubmodule }
  
  required init(submodule: any Submodule)
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
  
  // swiftlint:disable unused_setter_value
  private final class MockSubmodule: Submodule
  {
    let name = ""
    let path = ""
    let url: URL? = nil
    
    var ignoreRule: SubmoduleIgnore { get { .none } set {} }
    var updateStrategy: SubmoduleUpdate { get { .none } set {} }
    var recurse: SubmoduleRecurse { get { .no } set {} }

    func update(initialize: Bool, callbacks: RemoteCallbacks) throws {}
  }
}
