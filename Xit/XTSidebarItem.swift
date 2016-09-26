import Cocoa

class XTSideBarItem: NSObject
{
  var title: String
  var displayTitle: String { return title }
  var icon: NSImage? { return nil }
  var children: [XTSideBarItem]
  var model: XTFileChangesModel?
  var refType: XTRefType { return .unknown }
  var expandable: Bool { return false }
  var selectable: Bool { return true }
  var editable: Bool { return false }
  var current: Bool { return false }
  
  init(title: String)
  {
    self.title = title
    self.children = []
    
    super.init()
  }
  
  convenience init(title: String, model: XTFileChangesModel)
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


class XTSideBarGroupItem : XTSideBarItem
{
  override var selectable: Bool { return false }
  override var expandable: Bool { return true }
}


class XTRemotesItem : XTSideBarGroupItem
{}


class XTStagingItem : XTSideBarItem
{
  override var icon: NSImage? { return NSImage(named: "stagingTemplate") }
}


class XTStashItem : XTSideBarItem
{
  override var icon: NSImage? { return NSImage(named: "stashTemplate") }
}


class XTLocalBranchItem : XTSideBarItem
{
  override var displayTitle: String
      { return (title as NSString).lastPathComponent }
  override var icon: NSImage? { return NSImage(named: "branchTemplate") }
  override var refType: XTRefType { return .branch }
  override var current: Bool
  {
    if let currentBranch = self.model!.repository.currentBranch {
      return currentBranch == self.title
    }
    return false
  }
}


class XTRemoteBranchItem : XTLocalBranchItem
{
  var remote: String
  override var icon: NSImage? { return NSImage(named: "branchTemplate") }
  override var refType: XTRefType { return .remoteBranch }
  override var current: Bool { return false }
  
  init(title: String, remote: String, model: XTFileChangesModel)
  {
    self.remote = remote
    
    super.init(title: title)
    self.model = model
  }
}


class XTBranchFolderItem : XTSideBarItem
{
  override var icon: NSImage? { return NSImage(named: "folderTemplate") }
  override var selectable: Bool { return false }
  override var expandable: Bool { return true }
}


class XTRemoteItem : XTSideBarItem
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


class XTTagItem : XTSideBarItem
{
  let tag: XTTag

  override var icon: NSImage? { return NSImage(named: "tagTemplate") }
  override var refType: XTRefType { return .tag }
  
  init(tag: XTTag)
  {
    self.tag = tag
    
    super.init(title: tag.name)
    
    if let sha = tag.targetSHA {
      model = XTCommitChanges(repository: tag.repository, sha: sha)
    }
  }
}


class XTSubmoduleItem : XTSideBarItem
{
  var submodule: XTSubmodule
  override var icon: NSImage? { return NSImage(named: "submoduleTemplate") }
  
  init(submodule: XTSubmodule)
  {
    self.submodule = submodule
    
    super.init(title: submodule.name!)
  }
}
