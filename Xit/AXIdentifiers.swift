import Foundation

extension AXID
{
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
      static let mode = AXID("modePicker")
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
      static let tabStatus = AXID("tabStatus")
    }

    enum Toolbar
    {
      static let general = AXID("General")
    }
  }

  enum Sidebar
  {
    static let list = AXID("sidebar")
    static let filter = AXID("sidebarFilter")
    static let add = AXID("sidebarAdd")
    static let trackingStatus = AXID("trackingStatus")
    static let workspaceStatus = AXID("workspaceStatus")
  }
}
