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
    return item.displayTitle.rawValue.range(of: string,
                                            options: .caseInsensitive) != nil
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
