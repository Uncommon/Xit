import Cocoa

class XTSideBarItem: NSObject {
  var title: String
  var displayTitle: String { return title }
  var icon: NSImage? { return nil }
  var children: [XTSideBarItem]
  var model: XTFileChangesModel?
  var refType: XTRefType { return .Unknown }
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
  func addChild(child: XTSideBarItem)
  {
    self.children.append(child)
  }
  
  override var description: String { return self.title }
}


class XTSideBarGroupItem : XTSideBarItem {
  override var selectable: Bool { return false }
  override var expandable: Bool { return true }
}


class XTRemotesItem : XTSideBarGroupItem {}


class XTStagingItem : XTSideBarItem {
  override var icon: NSImage? { return NSImage(named: "stagingTemplate") }
}


class XTStashItem : XTSideBarItem {
  override var icon: NSImage? { return NSImage(named: "stashTemplate") }
}


class XTLocalBranchItem : XTSideBarItem {
  override var displayTitle: String
      { return (title as NSString).lastPathComponent }
  override var icon: NSImage? { return NSImage(named: "branchTemplate") }
  override var refType: XTRefType { return .Branch }
  override var editable: Bool { return true }
  override var current: Bool
  {
    if let currentBranch = self.model!.repository.currentBranch {
      return currentBranch == self.title
    }
    return false
  }
}


class XTRemoteBranchItem : XTLocalBranchItem {
  var remote: String
  override var icon: NSImage? { return NSImage(named: "branchTemplate") }
  override var refType: XTRefType { return .RemoteBranch }
  override var current: Bool { return false }
  
  init(title: String, remote: String, model: XTFileChangesModel)
  {
    self.remote = remote
    
    super.init(title: title)
    self.model = model
  }
}


class XTBranchFolderItem : XTSideBarItem {
  override var icon: NSImage? { return NSImage(named: "folderTemplate") }
  override var selectable: Bool { return false }
  override var expandable: Bool { return true }
}


class XTRemoteItem : XTSideBarItem {
  override var icon: NSImage? { return NSImage(named: "cloudTemplate") }
  override var expandable: Bool { return true }
  override var editable: Bool { return true }
  override var refType: XTRefType { return .Remote }
}



class XTTagItem : XTSideBarItem {
  override var icon: NSImage? { return NSImage(named: "tagTemplate") }
  override var refType: XTRefType { return .Tag }
}


class XTSubmoduleItem : XTSideBarItem {
  var submodule: GTSubmodule
  override var icon: NSImage? { return NSImage(named: "submoduleTemplate") }
  
  init(submodule: GTSubmodule)
  {
    self.submodule = submodule
    
    super.init(title: submodule.name!)
  }
}
