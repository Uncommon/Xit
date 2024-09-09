import XCTest
@testable import Xit

final class TreeItemTest: XCTestCase
{
  func testFlat() throws
  {
    let nodes = ["first", "second"]
    let items = TreeItem.makeHierarchy(from: nodes, pathKey: \.self)

    XCTAssertEqual(items, [
      .leaf("first"),
      .leaf("second"),
    ])
  }

  func testOneFolder()
  {
    let nodes = ["folder/item"]
    let items = TreeItem.makeHierarchy(from: nodes, pathKey: \.self)

    print(items.printed(pathKey: \.self))
    XCTAssertEqual(items, [
      .node(name: "folder", children: [.leaf("folder/item")]),
    ])
  }

  func testLevel2Folder()
  {
    let nodes = ["folder1/folder2/item"]
    let items = TreeItem.makeHierarchy(from: nodes, pathKey: \.self)

    print(items.printed(pathKey: \.self))
    XCTAssertEqual(items, [
      .node(name: "folder1", children: [
        .node(name: "folder2", children: [
          .leaf("folder1/folder2/item"),
        ]),
      ]),
    ])
  }

  func testItemIsFolder()
  {
    let nodes = ["folder", "folder/item"]
    let items = TreeItem.makeHierarchy(from: nodes, pathKey: \.self)

    print(items.printed(pathKey: \.self))
    XCTAssertEqual(items, [
      .node(name: "folder", item: "folder", children: [.leaf("folder/item")]),
    ])
  }
}

extension TreeItem
{
  func printed(pathKey: KeyPath<T, String>, indent: Int) -> String
  {
    let name: String
    switch self {
      case .leaf(let item):
        name = "- " + item[keyPath: pathKey].lastPathComponent
      case .node(let nodeName, let item, let children):
        name = (item == nil ? "+ " : "* ") + nodeName + "\n" + children.printed(pathKey: pathKey, indent: indent + 1)
    }
    return String(repeating: "  ", count: indent) + name
  }
}

extension Array
{
  func printed<T>(pathKey: KeyPath<T, String>, indent: Int = 0) -> String where Element == TreeItem<T>
  {
    map {
      $0.printed(pathKey: pathKey, indent: indent)
    }.joined(separator: "\n")
  }
}
