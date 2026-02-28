import XCTest
import AppKit
import SwiftUI
@testable import Xit

final class DummyDraggingSession: NSDraggingSession {}

@MainActor
final class CleanPanelDelegateMock: CleanPanelDelegate
{
  var onRefresh: (() -> Void)?

  func closePanel() {}
  func clean(_ files: [String]) throws {}
  func show(_ files: [String]) {}
  func refresh() { onRefresh?() }
}

@MainActor
final class CleanListTests: XCTestCase
{
  func testPasteboardWritersProduceFileURLs()
  {
    let model = CleanData()

    model.mode = .all
    model.items = [
      .init(path: "foo.txt", ignored: false),
      .init(path: "ignored.log", ignored: true),
    ]

    let rootURL = URL(fileURLWithPath: "/tmp/repo")
    var selection = Set<String>()
    let list = CleanList(data: model,
                         selection: Binding(get: { selection },
                                            set: { selection = $0 }),
                         delegate: nil,
                         fileURLForPath: { rootURL.appendingPathComponent($0) })
    let coordinator = list.makeCoordinator()
    let tableView = NSTableView()

    let writer0 = coordinator.tableView(tableView, pasteboardWriterForRow: 0)
    let writer1 = coordinator.tableView(tableView, pasteboardWriterForRow: 1)

    XCTAssertEqual(writer0 as? URL, rootURL.appendingPathComponent("foo.txt"))
    XCTAssertEqual(writer1 as? URL, rootURL.appendingPathComponent("ignored.log"))
  }

  func testPasteboardWriterOutOfBoundsIsNil()
  {
    let model = CleanData()
    var selection = Set<String>()
    let list = CleanList(data: model,
                         selection: Binding(get: { selection },
                                            set: { selection = $0 }),
                         delegate: nil,
                         fileURLForPath: { URL(fileURLWithPath: "/tmp/repo/" + $0) })
    let coordinator = list.makeCoordinator()
    let tableView = NSTableView()

    XCTAssertNil(coordinator.tableView(tableView, pasteboardWriterForRow: -1))
    XCTAssertNil(coordinator.tableView(tableView, pasteboardWriterForRow: 0))
  }

  func testDragSelectsClickedRows()
  {
    let model = CleanData()

    model.items = [
      .init(path: "foo.txt", ignored: false),
      .init(path: "bar.txt", ignored: false),
    ]

    var selection = Set<String>()
    let list = CleanList(data: model,
                         selection: Binding(get: { selection },
                                            set: { selection = $0 }),
                         delegate: nil,
                         fileURLForPath: { URL(fileURLWithPath: "/tmp/repo/\($0)") })
    let coordinator = list.makeCoordinator()
    let tableView = NSTableView()

    tableView.allowsMultipleSelection = true
    tableView.addTableColumn(.init(identifier: .init("file")))
    tableView.dataSource = coordinator
    tableView.delegate = coordinator
    tableView.reloadData()
    tableView.selectRowIndexes([0], byExtendingSelection: false)
    XCTAssertEqual(tableView.numberOfRows, 2)
    XCTAssertEqual(tableView.selectedRowIndexes, IndexSet([0]))

    coordinator.tableView(tableView,
                          draggingSession: DummyDraggingSession(),
                          willBeginAt: .zero,
                          forRowIndexes: [1])

    XCTAssertEqual(tableView.selectedRowIndexes, IndexSet([1]))
  }

  func testDragMoveTriggersRefresh()
  {
    let model = CleanData()
    model.items = [.init(path: "foo.txt", ignored: false)]

    var selection = Set<String>()
    let refreshExpectation = expectation(description: "refresh called")
    let delegate = CleanPanelDelegateMock()

    delegate.onRefresh = { refreshExpectation.fulfill() }

    let list = CleanList(data: model,
                         selection: Binding(get: { selection },
                                            set: { selection = $0 }),
                         delegate: delegate,
                         fileURLForPath: { URL(fileURLWithPath: "/tmp/repo/\($0)") })
    let coordinator = list.makeCoordinator()
    let tableView = NSTableView()

    coordinator.tableView(tableView,
                          draggingSession: DummyDraggingSession(),
                          endedAt: .zero,
                          operation: .move)

    wait(for: [refreshExpectation], timeout: 1.0)
  }
}
