import Foundation

/// An element in a hirerarchy of items where each item is identified by
/// a slash-separated path name.
enum TreeItem<T>
{
  /// An item in the hierarchy that never has child items
  case leaf(T)
  /// An item in the hierarchy with a possibly empty list of sub-items
  indirect case node(name: String, item: T? = nil, children: [Self])

  /// Creates a hierarchy from a list of items, adding container nodes
  /// for each "folder" represented in the path names.
  static func makeHierarchy(from items: [T],
                            pathKey: KeyPath<T, String>) -> [Self]
  {
    makeHierarchy(from: items.sorted(byKeyPath: pathKey),
                  pathKey: pathKey, prefix: "")
  }

  private static func makeHierarchy<C>(from items: C,
                                    pathKey: KeyPath<T, String>,
                                    prefix: String) -> [Self]
    where C: RandomAccessCollection<T>,
          C.Index == Int
  {
    var result: [Self] = []

    for var index in items.startIndex..<items.endIndex {
      let item = items[index]
      let path = item[keyPath: pathKey].droppingPrefix(prefix)
      let components = path.pathComponents

      if components.count > 1 {
        let pathPrefix = prefix + components[0] + "/"
        let subItems = items.dropFirst(index).prefix {
          $0[keyPath: pathKey].hasPrefix(pathPrefix)
        }
        let subHierarchy = makeHierarchy(from: subItems,
                                         pathKey: pathKey,
                                         prefix: pathPrefix)

        if case let .leaf(lastItem) = result.last,
           lastItem[keyPath: pathKey] == prefix + components[0] {
          _ = result.popLast()
          result.append(.node(name: components[0], item: lastItem, children: subHierarchy))
        }
        else {
          result.append(.node(name: components[0], item: nil, children: subHierarchy))
        }
        index += subItems.count
      }
      else {
        result.append(.leaf(item))
      }
    }

    return result
  }
}

extension TreeItem: Equatable where T: Equatable
{
  static func == (lhs: TreeItem<T>, rhs: TreeItem<T>) -> Bool
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
