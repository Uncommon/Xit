import Foundation

class FileChangesDataSource: FileListDataSourceBase
{
  var changes = [FileChange]()
  var wasInStaging: Bool = false
  
  func doReload(_ fileList: FileListModel?)
  {
    var newChanges = fileList?.changes ?? [FileChange]()
    
    newChanges.sort { $0.path < $1.path }
    
    let newPaths = newChanges.map { $0.path }
    let oldPaths = changes.map { $0.path }
    let newSet = NSOrderedSet(array: newPaths)
    let oldSet = NSOrderedSet(array: oldPaths)
    
    let deleteIndexes = oldSet.indexes(options: []) {
      (path, _, _) in !newSet.contains(path) }
    let addIndexes = newSet.indexes(options: []) {
      (path, _, _) in !oldSet.contains(path) }
    var newChangeIndexes = IndexSet()
    
    objc_sync_enter(self)
    defer { objc_sync_exit(self) }
    
    if changes.isEmpty {
      changes = newChanges
    }
    else {
      for change in changes {
        guard let newIndex = newChanges.index(where: {
          (newChange) in
          newChange.path == change.path &&
          newChange.change != change.change
        })
        else { continue }
        
        let newChange = newChanges[newIndex]
        
        change.change = newChange.change
        newChangeIndexes.insert(newIndex)
      }
      changes.removeObjects(at: deleteIndexes)
      changes.append(contentsOf: newChanges.objects(at: addIndexes))
      changes.sort { $0.path < $1.path }
    }
    
    DispatchQueue.main.async {
      [weak self] in
      guard let myself = self,
            let outlineView = myself.outlineView,
            myself === outlineView.dataSource
      else { return }
      let selectedRow = outlineView.selectedRow
      let selectedChange = myself.fileChange(at: selectedRow)
      
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
      myself.reselect(change: selectedChange, oldRow: selectedRow)
    }
  }
  
  func reselect(change: FileChange?, oldRow: Int)
  {
    guard let oldChange = change
    else {
      if outlineView.selectedRowIndexes.isEmpty {
        outlineView.selectRowIndexes(IndexSet(integer: 0),
                                     byExtendingSelection: false)
      }
      return
    }
    var newRow = 0
    
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

extension FileChangesDataSource: FileListDataSource
{
  func reload()
  {
    let model = repoController.selection.flatMap { self.model(for: $0) }
    
    repoController.queue.executeOffMainThread {
      [weak self] in
      self?.doReload(model)
    }
  }
  
  func fileChange(at row: Int) -> FileChange?
  {
    objc_sync_enter(self)
    defer { objc_sync_exit(self) }

    guard (row >= 0) && (row < changes.count)
    else { return nil }
    
    return row < changes.count ? changes[row] : nil
  }
  
  func path(for item: Any) -> String
  {
    return (item as? FileChange)?.path ?? ""
  }
  
  func change(for item: Any) -> DeltaStatus
  {
    guard let fileChange = item as? FileChange
    else { return .unmodified }
    
    return type(of: self).transformDisplayChange(fileChange.change)
  }
}

extension FileChangesDataSource: NSOutlineViewDataSource
{
  func outlineView(_ outlineView: NSOutlineView,
                   numberOfChildrenOfItem item: Any?) -> Int
  {
    objc_sync_enter(self)
    defer { objc_sync_exit(self) }
    
    return changes.count
  }

  func outlineView(_ outlineView: NSOutlineView,
                   child index: Int,
                   ofItem item: Any?) -> Any
  {
    objc_sync_enter(self)
    defer { objc_sync_exit(self) }
    
    return (index < changes.count) ? changes[index] : FileChange(path: "")
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
    return (item as? FileChange)?.path
  }
}
