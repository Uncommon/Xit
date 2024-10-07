import XCTest
@testable import Xit

final class PathTreeTest: XCTestCase
{
  func testFlat() throws
  {
    let nodes = ["first", "second"]
    let items = PathTreeNode.makeHierarchy(from: nodes)

    XCTAssertEqual(items, [
      .leaf("first"),
      .leaf("second"),
    ])
  }

  func testOneFolder()
  {
    let nodes = ["folder/item"]
    let items = PathTreeNode.makeHierarchy(from: nodes)

    print(items.printed())
    XCTAssertEqual(items, [
      .node(path: "folder", children: [.leaf("folder/item")]),
    ])
  }

  func testLevel2Folder()
  {
    let nodes = ["folder1/folder2/item"]
    let items = PathTreeNode.makeHierarchy(from: nodes)

    print(items.printed())
    XCTAssertEqual(items, [
      .node(path: "folder1", children: [
        .node(path: "folder1/folder2", children: [
          .leaf("folder1/folder2/item"),
        ]),
      ]),
    ])
  }

  func testLevel2FolderAsItems()
  {
    let nodes = [
      "folder1",
      "folder1/folder2",
      "folder1/folder2/item",
    ]
    let items = PathTreeNode.makeHierarchy(from: nodes)

    print(items.printed())
    XCTAssertEqual(items, [
      .node(item: "folder1", children: [
        .node(item: "folder1/folder2", children: [
          .leaf("folder1/folder2/item"),
        ]),
      ]),
    ])
  }

  func testItemIsFolder()
  {
    let nodes = ["folder", "folder/item", "other"]
    let items = PathTreeNode.makeHierarchy(from: nodes)

    print(items.printed())
    XCTAssertEqual(items, [
      .node(item: "folder", children: [
        .leaf("folder/item")]
      ),
      .leaf("other")
    ])
  }

  func testTwoSubItems()
  {
    let nodes = ["folder/item1", "folder/item2", "other"]
    let items = PathTreeNode.makeHierarchy(from: nodes)

    print(items.printed())
    XCTAssertEqual(items, [
      .node(path: "folder", children: [
        .leaf("folder/item1"),
        .leaf("folder/item2"),
      ]),
      .leaf("other")
    ])
  }
  
  func testSingeAndSubWithPrefx()
  {
    let nodes = ["refs/heads/main1", "refs/heads/work/things1"]
    let items = PathTreeNode.makeHierarchy(from: nodes, prefix: "refs/heads/")

    print(items.printed())
    XCTAssertEqual(items, [
      .leaf("refs/heads/main1"),
      .node(item: "refs/heads/work", children: [
        .leaf("refs/heads/work/things1")
      ])
    ])
  }

  func testFilter()
  {
    let data: [(nodes: [String], filter: String, expected: [String])] = [
      (["item"], "i", ["item"]),
      (["item"], "x", []),
      (["first", "second"], "nd", ["second"]),
      (["folder/item"], "i", ["folder/item"]),
      (["folder/item"], "x", []),
      (["folder", "folder/item"], "f", ["folder"]),
      (["folder", "folder/item"], "i", ["folder/item"]),
      (["folder/folder/item"], "i", ["folder/folder/item"]),
      (["folder/folder/item"], "x", []),
      (["folder/group/item"], "gr", []),
    ]

    for testCase in data {
      let items = PathTreeNode.makeHierarchy(from: testCase.nodes)
      let filtered = items.filtered(with: testCase.filter)
      let expectedNodes = PathTreeNode.makeHierarchy(from: testCase.expected)

      XCTAssertEqual(filtered, expectedNodes)
    }
  }
}

extension PathTreeNode
{
  func printed(indent: Int) -> String
  {
    let name: String
    switch self {
      case .leaf(let item):
        name = "- " + item.treeNodePath.lastPathComponent
      case .node(.virtual(let path), let children):
        name = "+ " + path.lastPathComponent + "\n" +
               children.printed(indent: indent + 1)
      case .node(.item(let item), let children):
        name = "* " + item.treeNodePath.lastPathComponent + "\n" +
               children.printed(indent: indent + 1)
    }
    return String(repeating: "  ", count: indent) + name
  }
}

extension Array
{
  func printed<T>(indent: Int = 0) -> String where Element == PathTreeNode<T>
  {
    map {
      $0.printed(indent: indent)
    }.joined(separator: "\n")
  }
}