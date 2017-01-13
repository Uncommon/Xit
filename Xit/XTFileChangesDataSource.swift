import Foundation

class XTFileChangesDataSource : XTFileListDataSourceBase
{
  var changes = [XTFileChange]()
  
  override var isHierarchical: Bool { return false }
  
  func doReload()
  {
    var newChanges = winController?.selectedModel?.changes ??
                     [XTFileChange]()
    
    newChanges.sort { $0.path < $1.path }
    
    let newPaths = newChanges.map { $0.path }
    let oldPaths = changes.map { $0.path }
    let newSet = NSOrderedSet(array: newPaths)
    let oldSet = NSOrderedSet(array: oldPaths)
    
    let deleteIndexes = oldSet.indexes(options: []) { !newSet.contains($0) }
    let addIndexes = newSet.indexes(options: []) { !oldSet.contains($0) }
    
    var changeIndexes = IndexSet()
    var newChangeIndexes = IndexSet()
    
    if !changes.isEmpty {
      changeIndexes = (changes as NSArray).indexesOfObjects(options: []) {
        (obj, index, stop) -> Bool in
        let change = obj as! XTFileChange
        guard let newIndex = newChanges.index(where: {
          (newChange) in
          newChange.path == change.path
        })
        else { return false }
        
        let newChange = newChanges[newIndex]
        
        if (newChange.change == change.change) &&
           (newChange.unstagedChange == change.unstagedChange) {
          return false
        }
        
        change.change = newChange.change
        change.unstagedChange = newChange.unstagedChange
        newChangeIndexes.insert(newIndex)
        return true
      }
      changes.removeObjects(at: deleteIndexes)
      changes.append(contentsOf: newChanges.objects(at: addIndexes))
      changes.sort { $0.path < $1.path }
    }
    else {
      changes = newChanges
    }
    
    DispatchQueue.main.async {
      [weak self] in
      guard let myself = self,
            let outlineView = myself.outlineView,
            self === outlineView.dataSource
      else { return }
      
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
      
      if changeIndexes.count > 0 {
        // Have to construct an NSIndexSet and then convert to IndexSet
        // because the compiler doesn't recognize the constructor.
        let range = NSRange(location: 0, length: outlineView.numberOfColumns)
        let allColumnIndexes = NSIndexSet(indexesIn: range) as IndexSet
        
        outlineView.reloadData(forRowIndexes: newChangeIndexes,
                               columnIndexes: allColumnIndexes)
      }
      if outlineView.selectedRow != -1 {
        outlineView.selectRowIndexes(NSIndexSet(index: 0) as IndexSet,
                                     byExtendingSelection: false)
      }
    }
  }
}

extension XTFileChangesDataSource : XTFileListDataSource
{
  func reload()
  {
    repository?.executeOffMainThread {
      [weak self] in
      self?.doReload()
    }
  }
  
  func fileChange(atRow row: Int) -> XTFileChange?
  {
    return row < changes.count ? changes[row] : nil
  }
  
  func path(forItem item: Any) -> String
  {
    return (item as? XTFileChange)?.path ?? ""
  }
  
  func change(forItem item: Any) -> XitChange
  {
    guard let fileChange = item as? XTFileChange
    else { return .unmodified }
    
    return type(of:self).transformDisplayChange(fileChange.change)
  }
  
  func unstagedChange(forItem item: Any) -> XitChange
  {
    guard let fileChange = item as? XTFileChange
    else { return .unmodified }
    
    return type(of:self).transformDisplayChange(fileChange.unstagedChange)
  }
}

extension XTFileChangesDataSource // NSOutlineViewDataSource
{
  override func outlineView(_ outlineView: NSOutlineView,
                            numberOfChildrenOfItem item: Any?) -> Int
  {
    return changes.count
  }

  override func outlineView(_ outlineView: NSOutlineView,
                            child index: Int,
                            ofItem item: Any?) -> Any
  {
    return (index < changes.count) ? changes[index] : XTFileChange()
  }

  override func outlineView(_ outlineView: NSOutlineView,
                            isItemExpandable item: Any) -> Bool
  {
    return false
  }

  override func outlineView(_ outlineView: NSOutlineView,
                   objectValueFor tableColumn: NSTableColumn?,
                   byItem item: Any?) -> Any?
  {
    guard let fileChange = item as? XTFileChange
    else { return nil }
    
    return fileChange.path
  }
}
