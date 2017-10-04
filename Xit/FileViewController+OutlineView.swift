import Foundation

extension FileViewController: NSOutlineViewDelegate
{
  private func displayChange(forChange change: XitChange,
                             otherChange: XitChange) -> XitChange
  {
    return (change == .unmodified) && (otherChange != .unmodified)
           ? .mixed : change
  }

  private func stagingImage(forChange change: XitChange,
                            otherChange: XitChange) -> NSImage?
  {
    let change = displayChange(forChange: change, otherChange: otherChange)
    
    return change.stageImage
  }

  func updateTableButton(_ button: NSButton,
                         change: XitChange, otherChange: XitChange)
  {
    button.image = modelCanCommit
        ? stagingImage(forChange: change, otherChange: otherChange)
        : change.changeImage
  }

  private func tableButtonView(_ identifier: NSUserInterfaceItemIdentifier,
                               change: XitChange,
                               otherChange: XitChange) -> TableButtonView
  {
    let cellView = fileListOutline.makeView(withIdentifier: identifier,
                                            owner: self)
                   as! TableButtonView
    let button = cellView.button!
    let displayChange = self.displayChange(forChange: change,
                                           otherChange: otherChange)
    
    (button.cell as! NSButtonCell).imageDimsWhenDisabled = false
    button.isEnabled = displayChange != .mixed
    updateTableButton(button, change: change, otherChange: otherChange)
    return cellView
  }

  func outlineView(_ outlineView: NSOutlineView,
                   viewFor tableColumn: NSTableColumn?,
                   item: Any) -> NSView?
  {
    guard let columnID = tableColumn?.identifier
    else { return nil }
    let dataSource = fileListDataSource
    let change = dataSource.change(for: item)
    
    switch columnID {
      
      case ColumnID.main:
        guard let cell = outlineView.makeView(withIdentifier: CellViewID.fileCell,
                                              owner: self) as? FileCellView
        else { return nil }
      
        let path = dataSource.path(for: item) as NSString
      
        cell.imageView?.image = dataSource.outlineView!(outlineView,
                                                       isItemExpandable: item)
                                ? NSImage(named: NSImage.Name.folder)
                                : NSWorkspace.shared
                                  .icon(forFileType: path.pathExtension)
        cell.textField?.stringValue = path.lastPathComponent
      
        var textColor: NSColor!
      
        if change == .deleted {
          textColor = NSColor.disabledControlTextColor
        }
        else if outlineView.isRowSelected(outlineView.row(forItem: item)) {
          textColor = NSColor.selectedTextColor
        }
        else {
          textColor = NSColor.textColor
        }
        cell.textField?.textColor = textColor
        cell.change = change
        return cell
      
      case ColumnID.staged:
        if inStagingView {
          return tableButtonView(
              CellViewID.staged,
              change: change,
              otherChange: dataSource.unstagedChange(for: item))
        }
        else {
          guard let cell = outlineView.makeView(withIdentifier: CellViewID.change,
                                            owner: self)
                           as? NSTableCellView
          else { return nil }
          
          cell.imageView?.image = change.changeImage
          return cell
        }
      
      case ColumnID.unstaged:
        if inStagingView {
          return tableButtonView(
              CellViewID.unstaged,
              change: dataSource.unstagedChange(for: item),
              otherChange: change)
        }
        else {
          return nil
        }
      
      default:
        return nil
    }
  }
  
  func outlineView(_ outlineView: NSOutlineView,
                   rowViewForItem item: Any) -> NSTableRowView?
  {
    return FileRowView()
  }
  
  func outlineView(_ outlineView: NSOutlineView,
                   didAdd rowView: NSTableRowView,
                   forRow row: Int)
  {
    (rowView as? FileRowView)?.outlineView = fileListOutline
  }
  
  func outlineViewSelectionDidChange(_ notification: Notification)
  {
    updateStagingSegment()
  }
}
