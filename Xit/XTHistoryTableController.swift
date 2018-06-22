import Cocoa

fileprivate let batchSize = 500

public class XTHistoryTableController: NSViewController
{
  enum ColumnID
  {
    static let commit = ¶"commit"
    static let date = ¶"date"
    static let name = ¶"name"
  }
  
  let observers = ObserverCollection()

  var tableView: NSTableView { return view as! NSTableView }
  var lastBatch = -1

  weak var repository: XTRepository!
  {
    didSet
    {
      history.repository = repository

      guard let table = view as? NSTableView
      else { return }
      var spacing = table.intercellSpacing
      
      spacing.height = 0
      table.intercellSpacing = spacing

      loadHistory()
      observers.addObserver(forName: .XTRepositoryRefsChanged,
                            object: repository, queue: .main) {
        [weak self] _ in
        // To do: dynamic updating
        // - new and changed refs: add if they're not already in the list
        // - deleted and changed refs: recursively remove unreferenced commits
        
        // For now: just reload
        self?.reload()
      }
      observers.addObserver(forName: .XTReselectModel,
                            object: repository, queue: .main) {
        [weak self] _ in
        guard let tableView = self?.view as? NSTableView,
              let selectedIndex = tableView.selectedRowIndexes.first
        else { return }
        
        tableView.scrollRowToCenter(selectedIndex)
      }
    }
  }
  
  let history = GitCommitHistory()
  
  deinit
  {
    let center = NotificationCenter.default
  
    center.removeObserver(self)
  }
  
  override public func viewDidLoad()
  {
    super.viewDidLoad()
  
    let controller = view.window?.windowController!
    
    observers.addObserver(
        forName: .XTSelectedModelChanged,
        object: controller,
        queue: .main) {
      [weak self] (notification) in
      if let selection = notification.userInfo?[NSKeyValueChangeKey.newKey]
                             as? RepositorySelection {
        self?.selectRow(sha: selection.shaToSelect)
      }
    }
    
    history.postProgress = {
      [weak self] in
      self?.postProgress(batchSize: $0, batch: $1, pass: $2, value: $3)
    }
  }
  
  /// Reloads the commit history from scratch.
  public func reload()
  {
    loadHistory()
    tableView.reloadData()
  }
  
  func loadHistory()
  {
    let repository = self.repository!
    let history = self.history
    weak var tableView = view as? NSTableView
    
    history.reset()
    repository.queue.executeOffMainThread {
      kdebug_signpost_start(Signposts.historyWalking, 0, 0, 0, 0)
      guard let walker = repository.walker()
      else {
        NSLog("RevWalker failed")
        return
      }
      
      walker.setSorting([.topological])
      
      let refs = repository.allRefs()
      
      for ref in refs where ref != "refs/stash" {
        repository.oid(forRef: ref).map { walker.push(oid: $0) }
      }
      
      objc_sync_enter(history)
      while let oid = walker.next() {
        guard let commit = repository.commit(forOID: oid)
        else { continue }
        
        history.appendCommit(commit)
      }
      objc_sync_exit(history)
      kdebug_signpost_end(Signposts.historyWalking, 0, 0, 0, 0)
      
      DispatchQueue.global(qos: .utility).async {
        // Get off the queue thread, but run this as a queue task so that
        // progress will be displayed.
        self.repository.queue.executeTask {
          kdebug_signpost_start(Signposts.connectCommits, 0, 0, 0, 0)
          history.connectCommits(batchSize: batchSize) {}
          kdebug_signpost_end(Signposts.connectCommits, 0, 0, 0, 0)
        }
        DispatchQueue.main.async {
          [weak self] in
          tableView?.reloadData()
          self?.ensureSelection()
        }
      }
    }
  }
  
  func postProgress(batchSize: Int, batch: Int, pass: Int, value: Int)
  {
    let passCount = 2
    let goal = history.entries.count * passCount
    let completed = batch * batchSize * passCount
    let totalProgress = completed + pass * passCount + value
  
    let step = goal / 100
    
    if (step == 0) || (totalProgress % step == 0) {
      let progressNote = Notification.progressNotification(
            repository: repository,
            progress: Float(totalProgress),
            total: Float(goal))
      
      NotificationCenter.default.post(progressNote)
    }
    
    if batch != lastBatch {
      weak var tableView = self.tableView
      
      lastBatch = batch
      DispatchQueue.main.async {
        guard let tableView = tableView
        else { return }
        
        switch batch {
          case 0:
            break
          case 1:
            tableView.reloadData()
          default:
            let batchStart = batch * batchSize
            let range = batchStart..<(batchStart+batchSize)
            let columnRange = 0..<tableView.tableColumns.count
            
            tableView.reloadData(forRowIndexes: IndexSet(integersIn: range),
                                 columnIndexes: IndexSet(integersIn: columnRange))
        }
      }
    }
  }
  
  func ensureSelection()
  {
    guard let tableView = view as? NSTableView,
          tableView.selectedRowIndexes.count == 0
    else { return }
    
    guard let controller = self.view.window?.windowController
                           as? RepositoryController,
          let selection = controller.selection
    else { return }
    
    selectRow(sha: selection.shaToSelect, forceScroll: true)
  }
  
  /// Selects the row for the given commit SHA.
  func selectRow(sha: String?, forceScroll: Bool = false)
  {
    let tableView = view as! NSTableView
    
    objc_sync_enter(self)
    objc_sync_enter(history)
    defer {
      objc_sync_exit(history)
      objc_sync_exit(self)
    }
    
    guard let sha = sha,
          let row = history.entries.index(where: { $0.commit.sha == sha })
    else {
      tableView.deselectAll(self)
      return
    }
    
    tableView.selectRowIndexes(IndexSet(integer: row),
                               byExtendingSelection: false)
    if forceScroll || (view.window?.firstResponder !== tableView) {
      tableView.scrollRowToCenter(row)
    }
  }
  
  public func refreshText()
  {
    for rowIndex in tableView.visibleRows() {
      guard let rowView = tableView.rowView(atRow: rowIndex,
                                            makeIfNecessary: false)
      else { continue }
      
      for column in 0..<rowView.numberOfColumns {
        guard let cellView = rowView.view(atColumn: column) as? NSTableCellView
        else { continue }
        
        setCellTextColor(cellView, index: rowIndex)
      }
    }
  }
  
  func setCellTextColor(_ cellView: NSTableCellView, index: Int)
  {
    let entry = history.entries[index]
    
    if let textField = cellView.textField {
      let deemphasize = (entry.commit.parentOIDs.count > 1) &&
          Preferences.deemphasizeMerges
      
      textField.textColor = deemphasize
          ? NSColor.disabledControlTextColor
          : NSColor.controlTextColor
    }
  }
}

extension XTHistoryTableController: NSTableViewDelegate
{
  public func tableView(_ tableView: NSTableView,
                        viewFor tableColumn: NSTableColumn?,
                        row: Int) -> NSView?
  {
    guard (row >= 0) && (row < history.entries.count)
    else {
      NSLog("Object value request out of bounds")
      return nil
    }
    guard let tableColumn = tableColumn,
          let result = tableView.makeView(withIdentifier: tableColumn.identifier,
                                          owner: self) as? NSTableCellView
    else { return nil }
    
    let entry = history.entries[row]
    
    switch tableColumn.identifier {
      case ColumnID.commit:
        let historyCell = result as! XTHistoryCellView
        
        historyCell.currentBranch = repository.currentBranch
        historyCell.refs = repository.refs(at: entry.commit.sha)
        historyCell.textField?.stringValue = entry.commit.message ?? ""
        historyCell.objectValue = entry
      case ColumnID.date:
        (result as! DateCellView).date = entry.commit.commitDate
      case ColumnID.name:
        var text: String
        
        if let name = entry.commit.authorName {
          if let email = entry.commit.authorEmail {
            text = "\(name) <\(email)>"
          }
          else {
            text = name
          }
        }
        else {
          text = entry.commit.authorEmail ?? "—"
        }
        result.textField?.stringValue = text
      default:
        return nil
    }
    
    setCellTextColor(result, index: row)
    
    return result
  }
 
  public func tableViewSelectionDidChange(_ notification: Notification)
  {
    guard view.window?.firstResponder === view,
          let tableView = notification.object as? NSTableView
    else { return }
    
    let selectedRow = tableView.selectedRow
    
    if (selectedRow >= 0) && (selectedRow < history.entries.count),
       let controller = view.window?.windowController as? RepositoryController {
      controller.selection =
          CommitSelection(repository: repository,
                          commit: history.entries[selectedRow].commit)
    }
  }
}

extension XTHistoryTableController: XTTableViewDelegate
{
  func tableViewClickedSelectedRow(_ tableView: NSTableView)
  {
    guard let selectionIndex = tableView.selectedRowIndexes.first,
          let controller = tableView.window?.windowController
                           as? RepositoryController
    else { return }
    
    let entry = history.entries[selectionIndex]
    let newSelection = CommitSelection(repository: repository,
                                       commit: entry.commit)
    
    if (controller.selection == nil) ||
       (controller.selection?.shaToSelect != newSelection.shaToSelect) ||
       (type(of: controller.selection!) != type(of: newSelection)) {
      controller.selection = newSelection
    }
  }
}

extension XTHistoryTableController: NSTableViewDataSource
{
  public func numberOfRows(in tableView: NSTableView) -> Int
  {
    return history.entries.count
  }
}
