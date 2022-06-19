import Foundation

extension AXID
{
  public enum Button
  {
    static let accept = AXID("acceptButton")
    static let cancel = AXID("cancelButton")
  }

  public enum Clean
  {
    static let window = AXID("cleanWindow")

    public enum Text
    {
      static let total = AXID("totalText")
      static let selected = AXID("selectedText")
    }

    public enum Controls
    {
      static let directories = AXID("directoriesCheck")
      static let fileMode = AXID("fileModePicker")
      static let folderMode = AXID("folderModePicker")
      static let filterType = AXID("filterType")
      static let filterField = AXID("filterField")
      static let fileList = AXID("fileList")
    }

    public enum Button
    {
      static let refresh = AXID("refreshButton")
      static let cancel = AXID("cancelButton")
      static let cleanSelected = AXID("cleanSelectedButton")
      static let cleanAll = AXID("cleanAllButton")
    }

    public enum List
    {
      static let fileName = AXID("fileName")
    }
  }

  enum FetchSheet
  {
    static let remotePopup = AXID("remote")
    static let tagsCheck = AXID("downloadTags")
    static let pruneCheck = AXID("pruneBranches")
  }

  enum Menu
  {
    static let branch = AXID("branchPopup")
    static let tag = AXID("tagPopup")
  }

  enum BranchPopup
  {
    static let checkOut = AXID("checkOutBranch")
    static let rename = AXID("renameBranch")
    static let merge = AXID("mergeBranch")
    static let delete = AXID("deleteBranch")
  }

  enum StashPopup
  {
    static let pop = AXID("popStash")
    static let apply = AXID("applyStash")
    static let drop = AXID("dropStash")
  }

  enum TagPopup
  {
    static let delete = AXID("deleteTag")
  }
  
  enum PopupMenu
  {
    static let pull = AXID("pullPopup")
    static let push = AXID("pushPopup")
    static let fetch = AXID("fetchPopup")
  }

  enum Preferences
  {
    static let window = AXID("Preferences")

    enum Controls
    {
      static let collapseHistory = AXID("collapseHistory")
      static let deemphasize = AXID("deemphasize")
      static let resetAmend = AXID("resetAmend")
      static let tabStatus = AXID("tabStatus")
    }

    enum Toolbar
    {
      static let general = AXID("General")
    }
  }

  enum Sidebar
  {
    static let add = AXID("sidebarAdd")
    static let currentBranch = AXID("currentBranch")
    static let filter = AXID("sidebarFilter")
    static let list = AXID("sidebar")
    static let trackingStatus = AXID("trackingStatus")
    static let workspaceStatus = AXID("workspaceStatus")
  }
}
