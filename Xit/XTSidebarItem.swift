import Cocoa

class XTSideBarItem: NSObject
{
  var title: String
  var displayTitle: String { return title }
  var icon: NSImage? { return nil }
  var children: [XTSideBarItem]
  var model: FileChangesModel?
  var refType: XTRefType { return .unknown }
  var expandable: Bool { return false }
  // NSObject.isSelectable is new in 10.12
  override var isSelectable: Bool { return true }
  var editable: Bool { return false }
  var current: Bool { return false }
  
  init(title: String)
  {
    self.title = title
    self.children = []
    
    super.init()
  }
  
  convenience init(title: String, model: FileChangesModel)
  {
    self.init(title: title)
    self.model = model
  }
  
  // Because children bridges as NSArray, not NSMutableArray.
  @objc(addChild:)  // Override default "addWithChild:"
  func add(child: XTSideBarItem)
  {
    self.children.append(child)
  }
  
  override var description: String { return self.title }
}


class XTSideBarGroupItem: XTSideBarItem
{
  override var isSelectable: Bool { return false }
  override var expandable: Bool { return true }
}


class XTRemotesItem: XTSideBarGroupItem
{}


class XTStagingItem: XTSideBarItem
{
  override var icon: NSImage? { return NSImage(named: "stagingTemplate") }
}


class XTStashItem: XTSideBarItem
{
  override var icon: NSImage? { return NSImage(named: "stashTemplate") }
}


class XTBranchItem: XTSideBarItem
{
  override var displayTitle: String
      { return (title as NSString).lastPathComponent }
  override var icon: NSImage? { return NSImage(named: "branchTemplate") }
  
  var fullName: String { return title }
}


class XTLocalBranchItem: XTBranchItem
{
  override var refType: XTRefType { return .branch }
  override var current: Bool
  {
    if let currentBranch = self.model!.repository.currentBranch {
      return currentBranch == self.title
    }
    return false
  }
  
  func hasTrackingBranch() -> Bool
  {
    return XTLocalBranch(repository: model!.repository,
                         name: title)?.trackingBranch != nil
  }
}


class XTRemoteBranchItem: XTBranchItem
{
  var remote: String
  override var refType: XTRefType { return .remoteBranch }
  
  override var fullName: String { return "\(remote)/\(title)" }
  
  init(title: String, remote: String, model: FileChangesModel)
  {
    self.remote = remote
    
    super.init(title: title)
    self.model = model
  }
}


class XTBranchFolderItem: XTSideBarItem
{
  override var icon: NSImage? { return NSImage(named: "folderTemplate") }
  override var isSelectable: Bool { return false }
  override var expandable: Bool { return true }
}


class XTRemoteItem: XTSideBarItem
{
  let remote: XTRemote?
  
  override var icon: NSImage?
  {
    if let urlString = remote?.urlString,
       let url = URL(string: urlString),
       let host = url.host {
      if (host == "github.com") || host.hasSuffix(".github.com") {
        return NSImage(named: "githubTemplate")
      }
    }
    return NSImage(named: "cloudTemplate")
  }
  
  override var expandable: Bool { return true }
  override var editable: Bool { return true }
  override var refType: XTRefType { return .remote }
  
  init(title: String, repository: XTRepository)
  {
    self.remote = XTRemote(name: title, repository: repository)
    
    super.init(title: title)
  }
}


class XTTagItem: XTSideBarItem
{
  let tag: Tag

  override var displayTitle: String
  { return (title as NSString).lastPathComponent }
  override var icon: NSImage? { return NSImage(named: "tagTemplate") }
  override var refType: XTRefType { return .tag }
  
  init(tag: Tag)
  {
    self.tag = tag
    
    super.init(title: tag.name)
    
    if let xtTag = tag as? XTTag,
       let sha = xtTag.targetSHA,
       let commit = XTCommit(sha: sha, repository: xtTag.repository) {
      self.model = CommitChanges(repository: xtTag.repository, commit: commit)
    }
  }
}


class XTSubmoduleItem: XTSideBarItem
{
  var submodule: XTSubmodule
  override var icon: NSImage? { return NSImage(named: "submoduleTemplate") }
  
  init(submodule: XTSubmodule)
  {
    self.submodule = submodule
    
    super.init(title: submodule.name!)
  }
}
