import Foundation

public protocol PathTreeData
{
  var treeNodePath: String { get }
}

/// An element in a hirerarchy of items where each item is identified by
/// a slash-separated path name.
enum PathTreeNode<T: PathTreeData>
{
  /// An item in the hierarchy that never has child items
  case leaf(T)
  /// An item in the hierarchy with a possibly empty list of sub-items
  indirect case node(path: String, item: T? = nil, children: [Self])

  var path: String
  {
    switch self {
      case .leaf(let item):
        return item.treeNodePath
      case .node(let path, let item, _):
        return item?.treeNodePath ?? path
    }
  }

  var children: [Self]?
  {
    switch self {
      case .leaf: nil
      case .node(_, _, let children): children
    }
  }

  var item: T?
  {
    switch self {
      case .leaf(let item): item
      case .node(_, let item, _): item
    }
  }
}

extension PathTreeNode
{
  /// Creates a hierarchy from a list of items, adding container nodes
  /// for each "folder" represented in the path names.
  static func makeHierarchy(from items: [T]) -> [Self]
  {
    // TODO: case insensitive sort
    makeHierarchy(from: items.sorted(byKeyPath: \.treeNodePath), prefix: "")
  }

  private static func makeHierarchy<C>(from items: C,
                                       prefix: String) -> [Self]
    where C: RandomAccessCollection<T>,
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
          result.append(.node(path: nodePath, item: lastItem, children: subHierarchy))
        }
        else {
          result.append(.node(path: nodePath, item: nil, children: subHierarchy))
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

extension PathTreeNode: Equatable where T: Equatable
{
  static func == (lhs: PathTreeNode<T>, rhs: PathTreeNode<T>) -> Bool
  {
    switch (lhs, rhs) {
      case (.leaf(let a), .leaf(let b)):
        a == b
      case (.node(let nameA, let itemA, let itemsA),
            .node(let nameB, let itemB, let itemsB)):
        nameA == nameB && itemA == itemB && itemsA == itemsB
      default:
        false
    }
  }
}
