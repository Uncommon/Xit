import Cocoa
import SwiftUI

struct CleanList: NSViewRepresentable
{
  @ObservedObject var data: CleanData
  @Binding var selection: Set<String>

  enum ColumnID
  {
    static let file = ¶"file"
    static let status = ¶"status"
  }

  func makeNSView(context: Context) -> NSScrollView
  {
    let tableView = NSTableView()
    let scrollView = NSScrollView()

    tableView.headerView = nil
    tableView.addTableColumn(.init(identifier: ColumnID.file))
    tableView.addTableColumn(.init(identifier: ColumnID.status))
    tableView.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
    tableView.tableColumns[1].width = 24
    tableView.allowsMultipleSelection = true
    tableView.delegate = context.coordinator
    tableView.dataSource = context.coordinator
    scrollView.documentView = tableView
    scrollView.borderType = .bezelBorder
    return scrollView
  }

  func makeCoordinator() -> Coordinator
  {
    Coordinator(data: data, selection: $selection)
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

    let ignoredImage = NSImage(systemSymbolName: "eye.slash")!
    let addImage = NSImage(systemSymbolName: "plus.circle")!
      .withSymbolConfiguration(.init(paletteColors: [.systemGreen]))!

    init(data: CleanData, selection: Binding<Set<String>>)
    {
      self.data = data
      self._selection = selection
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
        let view = NSView()
        let icon = item.icon
        let iconView = NSImageView(image: icon)

        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
          iconView.widthAnchor.constraint(equalToConstant: 16),
          iconView.heightAnchor.constraint(equalToConstant: 16),
        ])

        let stack = NSStackView(views: [
          iconView,
          NSTextField(labelWithString: item.path.lastPathComponent),
        ])

        stack.translatesAutoresizingMaskIntoConstraints = false
        view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
          stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
          stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
          stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        return view

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

    func tableView(_ tableView: NSTableView,
                   typeSelectStringFor tableColumn: NSTableColumn?,
                   row: Int) -> String?
    {
      data.filteredItems[row].path.lastPathComponent
    }
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
}

extension CleanList.Coordinator: NSTableViewDataSource
{
  func numberOfRows(in tableView: NSTableView) -> Int
  {
    data.filteredItems.count
  }
}
