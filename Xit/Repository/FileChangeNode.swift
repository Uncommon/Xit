import Foundation

public class TreeNode<T>
{
  var value: T
  var children: [TreeNode<T>] = []

  var isLeaf: Bool { children.isEmpty }

  init(value: T) {
    self.value = value
  }
}

extension TreeNode: Equatable where T: Comparable {
  public static func == (lhs: TreeNode<T>, rhs: TreeNode<T>) -> Bool
  {
    lhs.value == rhs.value
  }
}

extension TreeNode: Comparable where T: Comparable
{
  public static func < (lhs: TreeNode<T>, rhs: TreeNode<T>) -> Bool
  {
    lhs.value < rhs.value
  }

  public func sort()
  {
    children.sort()
    for child in children {
      child.sort()
    }
  }
}

extension TreeNode where T: CustomStringConvertible
{
  func dump(_ level: Int = 0)
  {
    print(String(repeating: "  ", count: level) + value.description)
    for child in children {
      child.dump(level + 1)
    }
  }
}

public typealias FileChangeNode = TreeNode<FileChange>

extension FileChangeNode
{
  static var rootPrefix: String { WorkspaceTreeBuilder.rootName + "/" }

  convenience init()
  {
    self.init(value: .init(path: ""))
  }

  func fileChangeNode(path: String) -> FileChangeNode?
  {
    return fileChangeNode(recursivePath: 
        path.withPrefix(FileChangeNode.rootPrefix))
  }

  private func fileChangeNode(recursivePath path: String) -> FileChangeNode?
  {
    if value.path == path {
      return self
    }

    guard path.hasPrefix(value.path)
    else { return nil }

    return children.firstResult { $0.fileChangeNode(recursivePath: path) }
  }

  @discardableResult
  func insert(fileChange: FileChange) -> FileChangeNode
  {
    let node = FileChangeNode(value: fileChange)

    children.insertSorted(node)
    return node
  }

  func add(fileChange newChange: FileChange)
  {
    var newChange = newChange

    newChange.path = newChange.path.withPrefix(FileChangeNode.rootPrefix)
    add(recursiveFileChange: newChange)
  }

  private func add(recursiveFileChange newChange: FileChange)
  {
    let myPath = value.path
    let newChangeParent = newChange.path.deletingLastPathComponent
      .withSuffix("/")

    if myPath == newChangeParent {
      insert(fileChange: newChange)
    }
    else {
      let subpath = newChange.path.droppingPrefix(myPath).droppingPrefix("/")
      guard let parentName = subpath.firstPathComponent
      else { return }

      if let parentNode = children.first(where: {
        $0.value.path.droppingPrefix(myPath)
        .firstPathComponent == parentName }) {
        parentNode.add(recursiveFileChange: newChange)
      }
      else {
        let nodePath = myPath.appending(pathComponent: parentName)
          .withSuffix("/")
        assert(nodePath.utf8.count <= newChange.path.utf8.count,
               "recursion error")
        let node = insert(fileChange: FileChange(path: nodePath,
                                                 change: .unmodified))

        node.add(recursiveFileChange: newChange)
      }
    }
  }
}
