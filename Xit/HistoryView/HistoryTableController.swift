import Cocoa

fileprivate let batchSize = 500

public class HistoryTableController: NSViewController
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
  
  public override func viewDidLoad()
  {
    super.viewDidLoad()
  
    tableView.setAccessibilityIdentifier("history")
    let controller = view.window?.windowController!
    
    observers.addObserver(
        forName: .XTSelectedModelChanged,
        object: controller,
        queue: .main) {
      [weak self] (notification) in
      guard let self = self,
            let selection = notification.userInfo?[NSKeyValueChangeKey.newKey]
                            as? RepositorySelection,
            // In spite of the `object` parameter, notifications can come through
            // for the wrong repository
            selection.repository.repoURL == self.repository.repoURL
      else { return }
      self.selectRow(sha: selection.shaToSelect)
    }
    
    history.postProgress = {
      [weak self] in
      self?.postProgress(pass: $0, start: $1, current: $2, end: $3)
    }
  }
  
  public override func viewWillDisappear()
  {
    history.abort()
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
    
    history.withSync {
      history.reset()
    }
    repository.queue.executeOffMainThread {
      Signpost.intervalStart(.historyWalking, object: self)
      defer {
        Signpost.intervalEnd(.historyWalking, object: self)
      }
      
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
      
      history.withSync {
        while let oid = walker.next() {
          guard let commit = repository.commit(forOID: oid)
          else { continue }
          
          history.appendCommit(commit)
        }
      }
      
      DispatchQueue.global(qos: .utility).async {
        // Get off the queue thread, but run this as a queue task so that
        // progress will be displayed.
        self.repository.queue.executeTask {
          Signpost.interval(.connectCommits) {
            history.processFirstBatch()
          }
        }
        DispatchQueue.main.async {
          [weak self] in
          tableView?.reloadData()
          self?.ensureSelection()
        }
      }
    }
  }
  
  /// Notifier for history processing progress
  /// - parameter pass: Currently there are two passes
  /// - parameter start: Row where the current task started
  /// - parameter current: Relative progress in the current pass
  /// - parameter end: Row where the task will end
  func postProgress(pass: Int, start: Int, current: Int, end: Int)
  {
    //print("\(start) - \(current) - \(end)")
    let passCount = 2
    let batch = start / batchSize
    let passSize = end - start
    let goal = passSize * passCount
    let totalProgress = pass * passSize + current
  
    let step = goal / 100
    
    if (step == 0) || (totalProgress % step == 0) {
      let progressNote = Notification.progressNotification(
            repository: repository,
            progress: Float(totalProgress),
            total: Float(goal))
      
      DispatchQueue.main.async {
        NotificationCenter.default.post(progressNote)
      }
    }
    
    if batch != lastBatch {
      lastBatch = batch
      DispatchQueue.main.async {
        [weak self] in
        guard let tableView = self?.tableView
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
            var viewRange: ClosedRange<Int>?
            
            tableView.enumerateAvailableRowViews {
              (rowView, row) in
              if let oldRange = viewRange {
                viewRange = min(row, oldRange.lowerBound)...max(row, oldRange.upperBound)
              }
              else {
                viewRange = row...row
              }
              
              if let cellView = rowView.view(atColumn: 0) as? HistoryCellView {
                cellView.needsUpdateConstraints = true
                cellView.needsDisplay = true
              }
              else {
                rowView.needsDisplay = true
              }
            }
            print("*** updated \(viewRange ?? 0...0)")
            tableView.reloadData(forRowIndexes: IndexSet(integersIn: range),
                                 columnIndexes: IndexSet(integersIn: columnRange))
        }
      }
    }
  }
  
  func ensureSelection()
  {
    guard let tableView = view as? NSTableView,
          tableView.selectedRowIndexes.isEmpty
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
          let row = history.entries.firstIndex(where: { $0.commit.sha == sha })
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
    let deemphasized = (entry.commit.parentOIDs.count > 1) &&
                       UserDefaults.standard.deemphasizeMerges

    if let textField = cellView.textField {

      textField.textColor = deemphasized
          ? NSColor.disabledControlTextColor
          : NSColor.controlTextColor
    }
    else if let historyCellView = cellView as? HistoryCellView {
      historyCellView.deemphasized = deemphasized
    }
  }
}

extension HistoryTableController: NSTableViewDelegate
{
  public func tableView(_ tableView: NSTableView,
                        viewFor tableColumn: NSTableColumn?,
                        row: Int) -> NSView?
  {
    let visibleRowCount =
          tableView.rows(in: tableView.enclosingScrollView!.bounds).length
    let firstProcessRow = min(history.entries.count, row + visibleRowCount)
    
    if firstProcessRow > history.batchStart
    {
      history.processBatches(throughRow: firstProcessRow,
                             queue: repository.queue)
    }
    
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
        let historyCell = result as! HistoryCellView
        
        historyCell.configure(entry: entry, repository: repository)

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

extension HistoryTableController: XTTableViewDelegate
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

extension HistoryTableController: NSTableViewDataSource
{
  public func numberOfRows(in tableView: NSTableView) -> Int
  {
    objc_sync_enter(history)
    defer {
      objc_sync_exit(history)
    }
    return history.entries.count
  }
}
