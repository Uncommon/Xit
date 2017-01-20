import Cocoa

public class XTHistoryTableController: NSViewController
{
  struct ColumnID
  {
    static let commit = "commit"
    static let date = "date"
    static let email = "email"
  }
  
  var refsChangedObserver: NSObjectProtocol?
  var selectionObserver: NSObjectProtocol?
  var reselectObserver: NSObjectProtocol?

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
      refsChangedObserver = NotificationCenter.default.addObserver(
          forName: NSNotification.Name.XTRepositoryRefsChanged,
          object: repository, queue: .main) {
        [weak self] _ in
        // To do: dynamic updating
        // - new and changed refs: add if they're not already in the list
        // - deleted and changed refs: recursively remove unreferenced commits
        
        // For now: just reload
        self?.reload()
      }
      reselectObserver = NotificationCenter.default.addObserver(
          forName: NSNotification.Name.XTReselectModel,
          object: repository, queue: .main) {
        [weak self] _ in
        guard let tableView = self?.view as? NSTableView,
              let selectedIndex = tableView.selectedRowIndexes.first
        else { return }
        
        tableView.scrollRowToCenter(selectedIndex)
      }
    }
  }
  
  let history = XTCommitHistory()
  
  deinit
  {
    let center = NotificationCenter.default
  
    refsChangedObserver.map { center.removeObserver($0) }
    selectionObserver.map { center.removeObserver($0) }
    reselectObserver.map { center.removeObserver($0) }
    center.removeObserver(self)
  }
  
  override public func viewDidAppear()
  {
    let controller = view.window?.windowController as! XTWindowController
    
    selectionObserver = NotificationCenter.default.addObserver(
        forName: NSNotification.Name.XTSelectedModelChanged,
        object: controller,
        queue: nil) {
      [weak self] (notification) in
      if let selectedModel = notification.userInfo?[NSKeyValueChangeKey.newKey]
                             as? XTFileChangesModel {
        self?.selectRow(sha: selectedModel.shaToSelect)
      }
    }
    NotificationCenter.default.addObserver(
        self,
        selector: #selector(XTHistoryTableController.dateViewResized(_:)),
        name: NSNotification.Name.NSViewFrameDidChange,
        object: nil)
  }
  
  /// Reloads the commit history from scratch.
  public func reload()
  {
    let tableView = view as! NSTableView
    
    loadHistory()
    tableView.reloadData()
  }
  
  func loadHistory()
  {
    let repository = self.repository!
    let history = self.history
    weak var tableView = view as? NSTableView
    
    history.reset()
    repository.executeOffMainThread {
      guard let walker = try? GTEnumerator(repository: repository.gtRepo)
      else {
        NSLog("GTEnumerator failed")
        return
      }
      
      walker.reset(options: [.topologicalSort, .timeSort])
      
      let refs = repository.allRefs()
      
      for ref in refs {
        _ = repository.sha(forRef: ref).flatMap { try? walker.pushSHA($0) }
      }
      
      while let gtCommit = walker.nextObject() as? GTCommit {
        guard let commit = XTCommit(oid: gtCommit.oid!, repository: repository)
        else { continue }
        
        history.appendCommit(commit)
      }
      
      history.connectCommits()
      DispatchQueue.main.async {
        tableView?.reloadData()
        self.ensureSelection()
      }
    }
  }
  
  func ensureSelection()
  {
    guard let tableView = view as? NSTableView,
          tableView.selectedRowIndexes.count == 0
    else { return }
    
    guard let controller = self.view.window?.windowController
                           as? XTWindowController,
          let selectedModel = controller.selectedModel
    else { return }
    
    selectRow(sha: selectedModel.shaToSelect, forceScroll: true)
  }
  
  /// Selects the row for the given commit SHA.
  func selectRow(sha: String?, forceScroll: Bool = false)
  {
    let tableView = view as! NSTableView
    
    guard let sha = sha,
          let row = history.entries.index(where: { $0.commit.sha == sha })
    else {
      tableView.deselectAll(self)
      return
    }
    
    tableView.selectRowIndexes(IndexSet(integer: row),
                               byExtendingSelection: false)
    if forceScroll || (view.window?.firstResponder != tableView) {
      tableView.scrollRowToCenter(row)
    }
  }
  
  func dateViewResized(_ notification: Notification)
  {
    guard let textField = notification.object as? NSTextField,
          let formatter = textField.cell?.formatter as? DateFormatter,
          let date = textField.objectValue as? Date
    else { return }
    
    updateDateStyle(formatter, width: textField.bounds.size.width)
    textField.stringValue = ""
    textField.objectValue = date
  }
  
  func updateDateStyle(_ formatter: DateFormatter, width: CGFloat)
  {
    let (dateStyle, timeStyle) = dateTimeStyle(width: width)
    
    formatter.dateStyle = dateStyle
    formatter.timeStyle = timeStyle
  }
}

let kFullStyleThreshold: CGFloat = 280
let kLongStyleThreshold: CGFloat = 210
let kMediumStyleThreshold: CGFloat = 170
let kShordStyleThreshold: CGFloat = 150

/// Calculates the appropriate date and time format for a given column width.
func dateTimeStyle(width: CGFloat) -> (date: DateFormatter.Style,
                                       time: DateFormatter.Style)
{
  var dateStyle = DateFormatter.Style.short
  var timeStyle = DateFormatter.Style.short
  
  switch width {
    case 0..<kShordStyleThreshold:
      timeStyle = .none
    case kShordStyleThreshold..<kMediumStyleThreshold:
      dateStyle = .short
    case kMediumStyleThreshold..<kLongStyleThreshold:
      dateStyle = .medium
    case kLongStyleThreshold..<kFullStyleThreshold:
      dateStyle = .long
    default:
      dateStyle = .full
  }
  return (dateStyle, timeStyle)
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
          let result = tableView.make(withIdentifier: tableColumn.identifier,
                                      owner: self) as? NSTableCellView
    else { return nil }
    
    let entry = history.entries[row]
    guard let sha = entry.commit.sha
    else { return nil }
    
    switch tableColumn.identifier {
      case ColumnID.commit:
        let historyCell = result as! XTHistoryCellView
        
        historyCell.refs = repository.refs(at: sha)
        historyCell.textField?.stringValue = entry.commit.message ?? ""
        historyCell.objectValue = entry
      case ColumnID.date:
        let textField = result.textField!
        let formatter = textField.cell!.formatter as! DateFormatter
        
        updateDateStyle(formatter, width: tableColumn.width)
        textField.objectValue = entry.commit.commitDate
        textField.postsFrameChangedNotifications = true
        textField.postsBoundsChangedNotifications = true
      case ColumnID.email:
        result.textField?.stringValue = entry.commit.email ?? ""
      default:
        return nil
    }
    return result
  }
 
  public func tableViewSelectionDidChange(_ notification: Notification)
  {
    guard view.window?.firstResponder == view,
          let tableView = notification.object as? NSTableView
    else { return }
    
    let selectedRow = tableView.selectedRow
    
    if (selectedRow >= 0) && (selectedRow < history.entries.count),
       let controller = view.window?.windowController as? XTWindowController,
       let sha = history.entries[selectedRow].commit.sha {
      controller.selectedModel = XTCommitChanges(repository: repository, sha: sha)
    }
  }
}

extension XTHistoryTableController: XTTableViewDelegate
{
  func tableViewClickedSelectedRow(_ tableView: NSTableView)
  {
    guard let selectionIndex = tableView.selectedRowIndexes.first,
          let controller = tableView.window?.windowController
                           as? XTWindowController
    else { return }
    
    let entry = history.entries[selectionIndex]
    guard let sha = entry.commit.sha
    else { return }
    let newModel = XTCommitChanges(repository: repository, sha: sha)
    
    if (controller.selectedModel == nil) ||
       (controller.selectedModel?.shaToSelect != newModel.shaToSelect) ||
       (type(of:controller.selectedModel!) != type(of:newModel)) {
      controller.selectedModel = newModel
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
