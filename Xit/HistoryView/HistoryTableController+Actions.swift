import Foundation

extension HistoryTableController: NSMenuItemValidation
{
  public func checkColumnItem(_ item: NSMenuItem,
                              columnID: NSUserInterfaceItemIdentifier) -> Bool
  {
    guard let column = tableView.tableColumn(withIdentifier: columnID)
    else { return false }

    item.state = column.isHidden ? .off : .on
    return true
  }

  public func validateMenuItem(_ item: NSMenuItem) -> Bool
  {
    switch item.action {

      case #selector(copySHA(sender:)):
        return true

      case #selector(resetToCommit(sender:)):
        if let (clickedRow, _) = tableView.contextMenuCell,
           clickedRow >= 0,
           let branchName = repository.currentBranch,
           let branch = repository.localBranch(named: branchName),
           let branchOID = branch.oid {
          return !branchOID.equals(history.entries[clickedRow].commit.oid)
        }
        else {
          return false
        }

      case #selector(showAuthorColumn(_:)):
        return checkColumnItem(item, columnID: ColumnID.author)
      case #selector(showAuthorDateColumn(_:)):
        return checkColumnItem(item, columnID: ColumnID.authorDate)
      case #selector(showCommitterColumn(_:)):
        return checkColumnItem(item, columnID: ColumnID.committer)
      case #selector(showCommitterDateColumn(_:)):
        return checkColumnItem(item, columnID: ColumnID.committerDate)
      case #selector(showSHAColumn(_:)):
        return checkColumnItem(item, columnID: ColumnID.sha)

      default:
        return false
    }
  }
}

extension HistoryTableController
{
  @IBAction func copySHA(sender: Any?)
  {
    guard let clickedCell = tableView.contextMenuCell
    else { return }
    let pasteboard = NSPasteboard.general

    pasteboard.clearContents()
    pasteboard.setString(history.entries[clickedCell.0].commit.sha,
                         forType: .string)
  }

  @IBAction func resetToCommit(sender: Any?)
  {
    guard let clickedCell = tableView.contextMenuCell,
          let windowController = view.window?.windowController
                                 as? XTWindowController
    else { return }

    windowController.startOperation {
      ResetOpController(windowController: windowController,
                        targetCommit: history.entries[clickedCell.0].commit)
    }
  }

  func toggleColumn(_ columnID: NSUserInterfaceItemIdentifier)
  {
    tableView.tableColumn(withIdentifier: columnID)?.isHidden.toggle()
  }

  @IBAction func showAuthorColumn(_ sender: Any)
  {
    toggleColumn(ColumnID.author)
  }

  @IBAction func showAuthorDateColumn(_ sender: Any)
  {
    toggleColumn(ColumnID.authorDate)
  }

  @IBAction func showCommitterColumn(_ sender: Any)
  {
    toggleColumn(ColumnID.committer)
  }

  @IBAction func showCommitterDateColumn(_ sender: Any)
  {
    toggleColumn(ColumnID.committerDate)
  }

  @IBAction func showSHAColumn(_ sender: Any)
  {
    toggleColumn(ColumnID.sha)
  }
}
