import Foundation

class XTFileChangesDataSource : FileListDataSourceBase
{
  var changes = [XTFileChange]()
  
  func doReload()
  {
    var newChanges = repoController?.selectedModel?.changes ??
                     [XTFileChange]()
    
    newChanges.sort { $0.path < $1.path }
    
    let newPaths = newChanges.map { $0.path }
    let oldPaths = changes.map { $0.path }
    let newSet = NSOrderedSet(array: newPaths)
    let oldSet = NSOrderedSet(array: oldPaths)
    
    let deleteIndexes = oldSet.indexes(options: []) {
      (path, index, stop) in !newSet.contains(path) }
    let addIndexes = newSet.indexes(options: []) {
      (path, index, stop) in !oldSet.contains(path) }
    var newChangeIndexes = IndexSet()
    
    if changes.isEmpty {
      changes = newChanges
    }
    else {
      changes.forEach {
        (change) in
        guard let newIndex = newChanges.index(where: {
          (newChange) in
          newChange.path == change.path &&
          ((newChange.change != change.change) ||
           (newChange.unstagedChange != change.unstagedChange))
        })
        else { return }
        
        let newChange = newChanges[newIndex]
        
        change.change = newChange.change
        change.unstagedChange = newChange.unstagedChange
        newChangeIndexes.insert(newIndex)
      }
      changes.removeObjects(at: deleteIndexes)
      changes.append(contentsOf: newChanges.objects(at: addIndexes))
      changes.sort { $0.path < $1.path }
    }
    
    DispatchQueue.main.async {
      [weak self] in
      guard let outlineView = self?.outlineView,
            self === outlineView.dataSource
      else { return }
      let selectedRow = outlineView.selectedRow
      let selectedChange = self?.fileChange(at: selectedRow)
      
      outlineView.beginUpdates()
      if !deleteIndexes.isEmpty {
        outlineView.removeItems(at: deleteIndexes,
                                inParent: nil,
                                withAnimation: .effectFade)
      }
      if !addIndexes.isEmpty {
        outlineView.insertItems(at: addIndexes,
                                inParent: nil,
                                withAnimation: .effectFade)
      }
      outlineView.endUpdates()
      
      if newChangeIndexes.count > 0 {
        // Have to construct an NSIndexSet and then convert to IndexSet
        // because the compiler doesn't recognize the constructor.
        let range = NSRange(location: 0, length: outlineView.numberOfColumns)
        let allColumnIndexes = NSIndexSet(indexesIn: range) as IndexSet
        
        outlineView.reloadData(forRowIndexes: newChangeIndexes,
                               columnIndexes: allColumnIndexes)
      }
      self?.reselect(change: selectedChange, oldRow: selectedRow)
    }
  }
  
  func reselect(change: XTFileChange?, oldRow: Int)
  {
    guard let oldChange = change
    else {
      if outlineView.selectedRowIndexes.isEmpty {
        outlineView.selectRowIndexes(IndexSet(integer: 0),
                                     byExtendingSelection: false)
      }
      return
    }
    var newRow = 0;
    
    if let oldRowChange = fileChange(at: oldRow),
       oldRowChange.path == oldChange.path {
      newRow = oldRow
    }
    else {
      if let matchRow = changes.index(where: { $0.path == oldChange.path }) {
        newRow = matchRow
      }
    }
    outlineView.selectRowIndexes(NSIndexSet(index: newRow) as IndexSet,
                                 byExtendingSelection: false)
  }
}

extension XTFileChangesDataSource : FileListDataSource
{
  var hierarchical: Bool { return false }

  func reload()
  {
    repository?.executeOffMainThread {
      [weak self] in
      self?.doReload()
    }
  }
  
  func fileChange(at row: Int) -> XTFileChange?
  {
    guard (row >= 0) && (row < changes.count)
    else { return nil }
    
    return row < changes.count ? changes[row] : nil
  }
  
  func path(for item: Any) -> String
  {
    return (item as? XTFileChange)?.path ?? ""
  }
  
  func change(for item: Any) -> XitChange
  {
    guard let fileChange = item as? XTFileChange
    else { return .unmodified }
    
    return type(of:self).transformDisplayChange(fileChange.change)
  }
  
  func unstagedChange(for item: Any) -> XitChange
  {
    guard let fileChange = item as? XTFileChange
    else { return .unmodified }
    
    return type(of:self).transformDisplayChange(fileChange.unstagedChange)
  }
}

extension XTFileChangesDataSource: NSOutlineViewDataSource
{
  func outlineView(_ outlineView: NSOutlineView,
                   numberOfChildrenOfItem item: Any?) -> Int
  {
    return changes.count
  }

  func outlineView(_ outlineView: NSOutlineView,
                   child index: Int,
                   ofItem item: Any?) -> Any
  {
    return (index < changes.count) ? changes[index] : XTFileChange()
  }

  func outlineView(_ outlineView: NSOutlineView,
                   isItemExpandable item: Any) -> Bool
  {
    return false
  }

  func outlineView(_ outlineView: NSOutlineView,
                   objectValueFor tableColumn: NSTableColumn?,
                   byItem item: Any?) -> Any?
  {
    return (item as? XTFileChange)?.path
  }
}
