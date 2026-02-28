import XCTest
import AppKit
import SwiftUI
@testable import Xit

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
}
