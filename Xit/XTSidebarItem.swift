import Cocoa

class XTSideBarItem: NSObject {

var title: String
var children: [XTSideBarItem]
var model: XTFileChangesModel?
var refType: XTRefType { return .Unknown } // only used for renaming
var expandable: Bool { return false }
var selectable: Bool { return true }

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


class XTStashItem : XTSideBarItem {}


class XTLocalBranchItem : XTSideBarItem {

override var refType: XTRefType { return .Branch }

}


class XTRemoteBranchItem : XTLocalBranchItem {

var remote: String
override var refType: XTRefType { return .RemoteBranch }

init(title: String, remote: String, model: XTFileChangesModel)
{
  self.remote = remote
  
  super.init(title: title)
  self.model = model
}

}


class XTRemoteItem : XTSideBarItem {

override var expandable: Bool { return true }
override var refType: XTRefType { return .Remote }

}



class XTTagItem : XTSideBarItem {

override var refType: XTRefType { return .Tag }

}


class XTSubmoduleItem : XTSideBarItem {

var submodule: GTSubmodule

init(submodule: GTSubmodule)
{
  self.submodule = submodule
  
  super.init(title: submodule.name!)
}

}
