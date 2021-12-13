import Foundation

extension HistoryTableController: NSMenuItemValidation
{
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
    guard let column = tableView.tableColumn(withIdentifier: columnID)
    else { return }

    column.isHidden.toggle()
    UserDefaults.standard.setShowColumn(columnID.rawValue,
                                        show: !column.isHidden)
  }
}

extension HistoryTableController: NSMenuDelegate
{
  func menuWillOpen(_ menu: NSMenu)
  {
    if menu === columnsMenu {
      let menuData: [(UIString, NSUserInterfaceItemIdentifier)] = [
        (.commit, ColumnID.commit),
        (.refs, ColumnID.refs),
        (.author, ColumnID.author),
        (.authorDate, ColumnID.authorDate),
        (.committer, ColumnID.committer),
        (.committerDate, ColumnID.committerDate),
        (.sha, ColumnID.sha),
      ]

      menu.setItems {
        for item in menuData {
          NSMenuItem(item.0) { _ in
            self.toggleColumn(item.1)
            if item.1 == ColumnID.refs {
              self.tableView.reloadData()
            }
          }.with(state: tableView.tableColumn(withIdentifier: item.1)?.isHidden
                 ?? true ? .off : .on)
        }
      }
    }
  }
}
