import Foundation

class FileChangesDataSource: FileListDataSourceBase
{
  var changes = [FileChange]()
  var wasInStaging: Bool = false
  
  func doReload(_ newChanges: [FileChange])
  {
    let newChanges = newChanges.sorted { $0.gitPath < $1.gitPath }
    
    let newPaths = newChanges.map { $0.gitPath }
    let oldPaths = changes.map { $0.gitPath }
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
        guard let newIndex = newChanges.firstIndex(where: {
          (newChange) in
          newChange.gitPath == change.gitPath &&
          newChange.status != change.status
        })
        else { continue }
        
        let newChange = newChanges[newIndex]
        
        change.status = newChange.status
        newChangeIndexes.insert(newIndex)
      }
      changes.removeObjects(at: deleteIndexes)
      changes.append(contentsOf: newChanges.objects(at: addIndexes))
      changes.sort { $0.gitPath < $1.gitPath }
    }
    
    DispatchQueue.main.async {
      [weak self] in
      guard let self = self,
            let outlineView = self.outlineView,
            self === outlineView.dataSource
      else { return }
      let selectedRow = outlineView.selectedRow
      let selectedChange = self.fileChange(at: selectedRow)
      
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
      
      if !newChangeIndexes.isEmpty {
        // Have to construct an NSIndexSet and then convert to IndexSet
        // because the compiler doesn't recognize the constructor.
        let range = NSRange(location: 0, length: outlineView.numberOfColumns)
        let allColumnIndexes = NSIndexSet(indexesIn: range) as IndexSet
        
        outlineView.reloadData(forRowIndexes: newChangeIndexes,
                               columnIndexes: allColumnIndexes)
      }
      self.reselect(change: selectedChange, oldRow: selectedRow)
    }
  }
  
  func reselect(change: FileChange?, oldRow: Int)
  {
    guard let oldChange = change
    else { return }
    var newRow = 0
    
    if let oldRowChange = fileChange(at: oldRow),
       oldRowChange.gitPath == oldChange.gitPath {
      newRow = oldRow
    }
    else {
      if let matchRow = changes.firstIndex(
            where: { $0.gitPath == oldChange.gitPath }) {
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
    let model = repoUIController.selection.flatMap { self.model(for: $0) }
    
    if let delegate = self.delegate,
       let finalModel = model {
      delegate.configure(model: finalModel)
    }
    
    let newChanges = model?.changes ?? []
    
    repoUIController.queue.executeOffMainThread {
      [weak self] in
      self?.doReload(newChanges)
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
    return (item as? FileChange)?.gitPath ?? ""
  }
  
  func change(for item: Any) -> DeltaStatus
  {
    guard let fileChange = item as? FileChange
    else { return .unmodified }
    
    return type(of: self).transformDisplayChange(fileChange.status)
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
    return (item as? FileChange)?.gitPath
  }
}
