import Cocoa
import SwiftUI

struct CleanList: NSViewRepresentable
{
  @ObservedObject var data: CleanData
  @Binding var selection: Set<String>
  weak var delegate: (any CleanPanelDelegate)?
  let fileURLForPath: (String) -> URL

  enum ColumnID
  {
    static let file = ¶"file"
    static let status = ¶"status"
  }

  enum ReuseID
  {
    static let fileCell = ¶"fileCell"
  }

  func makeNSView(context: Context) -> NSScrollView
  {
    let tableView = NSTableView()
    let scrollView = NSScrollView()
    let nib = NSNib(nibNamed: "CleanCell", bundle: nil)

    tableView.register(nib, forIdentifier: ReuseID.fileCell)
    tableView.headerView = nil
    tableView.addTableColumn(.init(identifier: ColumnID.file))
    tableView.addTableColumn(.init(identifier: ColumnID.status))
    tableView.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
    tableView.tableColumns[1].width = 24
    tableView.allowsMultipleSelection = true
    tableView.registerForDraggedTypes([.fileURL])
    tableView.delegate = context.coordinator
    tableView.dataSource = context.coordinator
    scrollView.documentView = tableView
    scrollView.borderType = .bezelBorder
    context.coordinator.setMenu(for: tableView)
    return scrollView
  }

  func makeCoordinator() -> Coordinator
  {
    Coordinator(data: data, selection: $selection, delegate: delegate,
                fileURLForPath: fileURLForPath)
  }

  func updateNSView(_ nsView: NSScrollView, context: Context)
  {
    let tableView = nsView.documentView as! NSTableView
    let selectedRows = tableView.selectedRowIndexes

    tableView.reloadData()
    // reloadData() loses the selection
    tableView.selectRowIndexes(selectedRows, byExtendingSelection: false)
  }

  class Coordinator: NSObject
  {
    let data: CleanData
    @Binding var selection: Set<String>
    weak var delegate: (any CleanPanelDelegate)?
    let fileURLForPath: (String) -> URL

    let ignoredImage = NSImage(systemSymbolName: "eye.slash")!
    let addImage = NSImage(systemSymbolName: "plus.circle")!
      .withSymbolConfiguration(.init(paletteColors: [.systemGreen]))!

    init(data: CleanData, selection: Binding<Set<String>>,
         delegate: (any CleanPanelDelegate)? ,
         fileURLForPath: @escaping (String) -> URL)
    {
      self.data = data
      self._selection = selection
      self.delegate = delegate
      self.fileURLForPath = fileURLForPath
    }
    
    @MainActor
    func setMenu(for tableView: NSTableView) {
      let menu = NSMenu {
        NSMenuItem(.showInFinder) { _ in
          // User may have right-clicked on a row outside the selection
          let indexes = tableView.selectedRowIndexes
          let row = tableView.clickedRow
          let targetIndexes = indexes.contains(row) ? indexes : [row]
          let paths = targetIndexes
                .map { self.data.filteredItems[$0].path }
          
          self.delegate?.show(paths)
        }
      }

      tableView.menu = menu
    }
  }
}

extension CleanList.Coordinator: NSTableViewDelegate
{
  func tableView(_ tableView: NSTableView,
                 viewFor tableColumn: NSTableColumn?,
                 row: Int) -> NSView?
  {
    guard let columnID = tableColumn?.identifier
    else { return nil }
    let item = data.filteredItems[row]

    switch columnID {
      case CleanList.ColumnID.file:
        guard let cell = tableView.makeView(
            withIdentifier: CleanList.ReuseID.fileCell, owner: nil)
            as? NSTableCellView
        else { return nil }

        cell.imageView?.image = item.icon
        cell.textField?.stringValue = item.path.lastPathComponent
        return cell

      case CleanList.ColumnID.status:
        let view = NSView()
        let icon = item.ignored ? ignoredImage : addImage
        let imageView = NSImageView(image: icon)

        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageView)
        NSLayoutConstraint.activate([
          imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
          imageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        return view

      default:
        return nil
    }
  }

  func tableView(_ tableView: NSTableView,
                 typeSelectStringFor tableColumn: NSTableColumn?,
                 row: Int) -> String?
  {
    data.filteredItems[row].path.lastPathComponent
  }

  func tableViewSelectionDidChange(_ notification: Notification)
  {
    guard let tableView = notification.object as? NSTableView
    else { return }
    let rows = tableView.selectedRowIndexes

    // Make sure this happens outside a SwiftUI view update
    Task {
      selection = Set(rows.map { data.filteredItems[$0].path })
    }
  }

  func tableView(_ tableView: NSTableView,
                 pasteboardWriterForRow row: Int) -> NSPasteboardWriting?
  {
    guard row >= 0 && row < data.filteredItems.count else { return nil }
    let path = data.filteredItems[row].path

    return fileURLForPath(path) as NSURL
  }
}

extension CleanList.Coordinator: NSTableViewDataSource
{
  func numberOfRows(in tableView: NSTableView) -> Int
  {
    data.filteredItems.count
  }
}
