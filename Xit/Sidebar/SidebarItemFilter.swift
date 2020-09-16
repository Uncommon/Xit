import Foundation

/// A filter that determines if sidebar items should be displayed
protocol SidebarItemFilter
{
  func check(_ item: SidebarItem) -> Bool
}

/// Shows only items whose name contains a string
struct SidebarNameFilter: SidebarItemFilter
{
  let string: String
  
  func check(_ item: SidebarItem) -> Bool
  {
    return item.displayTitle
               .rawValue
               .range(of: string,
                      options: [.caseInsensitive, .diacriticInsensitive]) != nil
  }
}

/// Filters out branches older than a date
struct SidebarDateFilter: SidebarItemFilter
{
  let dateLimit: Date
  
  func check(_ item: SidebarItem) -> Bool
  {
    switch item {
      
      case let branchItem as BranchSidebarItem:
        guard let commit = branchItem.branchObject()?.targetCommit,
              let date = commit.authorDate
        else { return false }
      
        return date >= dateLimit
      
      default:
        return true
    }
  }
}

struct SidebarFilterSet
{
  var filters: [SidebarItemFilter]
  
  func apply(to roots: [SideBarGroupItem]) -> [SideBarGroupItem]
  {
    guard !filters.isEmpty
    else { return roots }
    
    var result: [SideBarGroupItem] = []
    
    for (index, root) in roots.enumerated() {
      switch SidebarGroupIndex(rawValue: index) {
        case .workspace?, .stashes?, .submodules?:
          result.append(root)
        case .branches?, .tags?:
          result.append(filter(root: root) as! SideBarGroupItem)
        case .remotes?:
          let newRemotes = SideBarGroupItem(titleString: .remotes)
        
          for remote in root.children {
            newRemotes.children.append(filter(root: remote))
          }
          result.append(newRemotes)
        default:
          continue
      }
    }
    return result
  }
  
  func filter(root: SidebarItem) -> SidebarItem
  {
    let copy = root.shallowCopy()
    
    for child in root.children {
      if child.children.isEmpty {
        if filters.allSatisfy({ $0.check(child) }) {
          copy.children.append(child.shallowCopy())
        }
      }
      else {
        let filteredChild = filter(root: child)
        
        if !(filteredChild.children.isEmpty &&
             filteredChild is BranchFolderSidebarItem) {
          copy.children.append(filteredChild)
        }
      }
    }
    return copy
  }
}
