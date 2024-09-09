import XCTest
@testable import Xit

extension String: TreeItemData
{
  public var treeItemPath: String { self }
}

final class TreeItemTest: XCTestCase
{
  func testFlat() throws
  {
    let nodes = ["first", "second"]
    let items = TreeItem.makeHierarchy(from: nodes)

    XCTAssertEqual(items, [
      .leaf("first"),
      .leaf("second"),
    ])
  }

  func testOneFolder()
  {
    let nodes = ["folder/item"]
    let items = TreeItem.makeHierarchy(from: nodes)

    print(items.printed())
    XCTAssertEqual(items, [
      .node(path: "folder", children: [.leaf("folder/item")]),
    ])
  }

  func testLevel2Folder()
  {
    let nodes = ["folder1/folder2/item"]
    let items = TreeItem.makeHierarchy(from: nodes)

    print(items.printed())
    XCTAssertEqual(items, [
      .node(path: "folder1", children: [
        .node(path: "folder1/folder2", children: [
          .leaf("folder1/folder2/item"),
        ]),
      ]),
    ])
  }

  func testItemIsFolder()
  {
    let nodes = ["folder", "folder/item"]
    let items = TreeItem.makeHierarchy(from: nodes)

    print(items.printed())
    XCTAssertEqual(items, [
      .node(path: "folder", item: "folder", children: [.leaf("folder/item")]),
    ])
  }
}

extension TreeItem
{
  func printed(indent: Int) -> String
  {
    let name: String
    switch self {
      case .leaf(let item):
        name = "- " + item.treeItemPath.lastPathComponent
      case .node(let nodeName, let item, let children):
        name = (item == nil ? "+ " : "* ") + nodeName + "\n" + children.printed(indent: indent + 1)
    }
    return String(repeating: "  ", count: indent) + name
  }
}

extension Array
{
  func printed<T>(indent: Int = 0) -> String where Element == TreeItem<T>
  {
    map {
      $0.printed(indent: indent)
    }.joined(separator: "\n")
  }
}
