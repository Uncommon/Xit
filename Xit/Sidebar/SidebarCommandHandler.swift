import Foundation

// Command handling extracted for testability
protocol SidebarCommandHandler: AnyObject, RepositoryUIAccessor
{
  var window: NSWindow? { get }
  
  func targetItem() -> SidebarItem?
  func stashIndex(for item: SidebarItem) -> UInt?
}

enum SidebarGroupIndex: Int
{
  case workspace
  case branches
  case remotes
  case tags
  case stashes
  case submodules
}

extension SidebarCommandHandler
{
  typealias Repository =
      BasicRepository & WritingManagement & Branching & Stashing
  
  var repository: Repository { repoUIController!.repository }
  
  func validate(sidebarCommand: NSMenuItem) -> Bool
  {
    guard let action = sidebarCommand.action,
          let item = targetItem()
    else { return false }
    
    switch action {
      
      case #selector(SidebarController.checkOutBranch(_:)):
        guard let branch = (item as? BranchSidebarItem)?.branchObject()
        else { return false }
        sidebarCommand.titleString = .checkOut(branch.strippedName)
        return !repository.isWriting && item.title != repository.currentBranch
      
      case #selector(SidebarController.createTrackingBranch(_:)):
        return !repository.isWriting && item is RemoteBranchSidebarItem
      
      case #selector(SidebarController.renameBranch(_:)),
           #selector(SidebarController.mergeBranch(_:)),
           #selector(SidebarController.deleteBranch(_:)):
        if !item.refType.isBranch || repository.isWriting {
          return false
        }
        if action == #selector(SidebarController.renameBranch(_:)) {
          sidebarCommand.isHidden = item.refType == .remoteBranch
        }
        if action == #selector(SidebarController.deleteBranch(_:)) {
          return repository.currentBranch != item.title
        }
        if action == #selector(SidebarController.mergeBranch(_:)) {
          var clickedBranch = item.title

          switch item.refType {
            case .remoteBranch:
              guard let remoteItem = item as? RemoteBranchSidebarItem
              else { return false }
              
              clickedBranch = "\(remoteItem.remoteName)/\(clickedBranch)"
            case .activeBranch:
              return false
            default:
              break
          }
          
          guard let currentBranch = repository.currentBranch
          else { return false }
          
          sidebarCommand.titleString = .merge(clickedBranch, currentBranch)
        }
        return true
      
      case #selector(SidebarController.deleteTag(_:)):
        return !repository.isWriting && (item is TagSidebarItem)
      
      case #selector(SidebarController.renameRemote(_:)),
           #selector(SidebarController.editRemote(_:)),
           #selector(SidebarController.deleteRemote(_:)):
        return !repository.isWriting && (item is RemoteSidebarItem)
      
      case #selector(SidebarController.copyRemoteURL(_:)):
        return item is RemoteSidebarItem
      
      case #selector(SidebarController.popStash(_:)),
           #selector(SidebarController.applyStash(_:)),
           #selector(SidebarController.dropStash(_:)):
        return !repository.isWriting && item is StashSidebarItem
      
      case #selector(SidebarController.showSubmodule(_:)):
        return item is SubmoduleSidebarItem
      
      case #selector(SidebarController.updateSubmodule(_:)):
        return !repository.isWriting && item is SubmoduleSidebarItem
      
      default:
        return false
    }
  }
  
  func callCommand(targetItem: SidebarItem? = nil,
                   block: @escaping (SidebarItem) throws -> Void)
  {
    guard let item = targetItem ?? self.targetItem()
    else { return }
    
    repoUIController?.queue.executeOffMainThread {
      do {
        try block(item)
      }
      catch let error as NSError {
        DispatchQueue.main.async {
          guard let window = self.window
          else { return }
          let alert = NSAlert(error: error)
          
          alert.beginSheetModal(for: window, completionHandler: nil)
        }
      }
    }
  }

  func popStash()
  {
    callCommand {
      [weak self] (item) in
      guard let index = self?.stashIndex(for: item)
      else { return }
      
      try self?.repository.popStash(index: index)
    }
  }
  
  func applyStash()
  {
    callCommand {
      [weak self] (item) in
      guard let index = self?.stashIndex(for: item)
      else { return }
      
      try self?.repository.applyStash(index: index)
    }
  }
  
  func dropStash()
  {
    callCommand {
      [weak self] (item) in
      guard let index = self?.stashIndex(for: item)
      else { return }
      
      try self?.repository.dropStash(index: index)
    }
  }
}
