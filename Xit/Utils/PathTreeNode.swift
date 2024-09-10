import Foundation

public protocol PathTreeData
{
  var treeNodePath: String { get }
}

/// An element in a hirerarchy of items where each item is identified by
/// a slash-separated path name.
enum PathTreeNode<Item: PathTreeData>
{
  /// An item in the hierarchy that never has child items
  case leaf(Item)
  /// An item in the hierarchy with a possibly empty list of sub-items
  indirect case node(content: NodeContent<Item>, children: [Self])

  static func node(path: String, children: [Self]) -> Self
  {
    .node(content: .virtual(path: path), children: children)
  }

  static func node(item: Item, children: [Self]) -> Self
  {
    .node(content: .item(item), children: children)
  }

  var path: String
  {
    switch self {
      case .leaf(let item):
        return item.treeNodePath
      case .node(let content, _):
        return content.path
    }
  }

  var children: [Self]?
  {
    switch self {
      case .leaf: nil
      case .node(_, let children): children
    }
  }

  var item: Item?
  {
    switch self {
      case .leaf(let item): item
      case .node(.item(let item), _): item
      default: nil
    }
  }
}

enum NodeContent<Item: PathTreeData>
{
  case virtual(path: String)
  case item(Item)

  var path: String
  {
    switch self {
      case .virtual(let path): path
      case .item(let item): item.treeNodePath
    }
  }
}

extension NodeContent: Equatable where Item: Equatable
{
  static func == (lhs: NodeContent<Item>, rhs: NodeContent<Item>) -> Bool
  {
    lhs.path == rhs.path
  }
}

extension PathTreeNode
{
  /// Creates a hierarchy from a list of items, adding container nodes
  /// for each "folder" represented in the path names.
  static func makeHierarchy(from items: [Item]) -> [Self]
  {
    // TODO: case insensitive sort
    makeHierarchy(from: items.sorted(byKeyPath: \.treeNodePath), prefix: "")
  }

  private static func makeHierarchy<C>(from items: C,
                                       prefix: String) -> [Self]
    where C: RandomAccessCollection<Item>,
          C.Index == Int
  {
    var result: [Self] = []
    var index = items.startIndex

    repeat {
      let item = items[index]
      let path = item.treeNodePath.droppingPrefix(prefix)
      let components = path.pathComponents

      if components.count > 1 {
        let pathPrefix = prefix + components[0] + "/"
        let subItems = items.dropFirst(index).prefix {
          $0.treeNodePath.hasPrefix(pathPrefix)
        }
        let subHierarchy = makeHierarchy(from: subItems, prefix: pathPrefix)
        let nodePath = prefix + components[0]

        if case let .leaf(lastItem) = result.last,
           lastItem.treeNodePath == prefix + components[0] {
          _ = result.popLast()
          result.append(.node(item: lastItem, children: subHierarchy))
        }
        else {
          result.append(.node(path: nodePath, children: subHierarchy))
        }
        index += subItems.count
      }
      else {
        result.append(.leaf(item))
        index += 1
      }
    } while index < items.endIndex

    return result
  }
}

extension PathTreeNode: Equatable where Item: Equatable
{
  static func == (lhs: PathTreeNode<Item>, rhs: PathTreeNode<Item>) -> Bool
  {
    switch (lhs, rhs) {
      case (.leaf(let a), .leaf(let b)):
        a == b
      case (.node(let contentA, let itemsA),
            .node(let contentB, let itemsB)):
        contentA == contentB && itemsA == itemsB
      default:
        false
    }
  }
}
