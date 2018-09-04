import Foundation

extension NSTreeNode
{
  var fileChange: FileChange { return representedObject as! FileChange }
  static var rootPrefix: String { return WorkspaceTreeBuilder.rootName + "/" }
  
  func fileChangeNode(path: String) -> NSTreeNode?
  {
    return fileChangeNode(recursivePath: path.withPrefix(NSTreeNode.rootPrefix))
  }
  
  private func fileChangeNode(recursivePath path: String) -> NSTreeNode?
  {
    if fileChange.path == path {
      return self
    }
    
    guard path.hasPrefix(fileChange.path)
    else { return nil }
    
    return children?.firstResult { $0.fileChangeNode(recursivePath: path) }
  }
  
  @discardableResult
  func insert(fileChange: FileChange) -> NSTreeNode
  {
    let node = NSTreeNode(representedObject: fileChange)
    
    insert(node: node) { $0.fileChange.path }
    return node
  }
  
  func add(fileChange newChange: FileChange)
  {
    newChange.path = newChange.path.withPrefix(NSTreeNode.rootPrefix)
    add(recursiveFileChange: newChange)
  }
  
  private func add(recursiveFileChange newChange: FileChange)
  {
    let myPath = fileChange.path
    let newChangeParent = newChange.path.deletingLastPathComponent
                                        .withSuffix("/")
    
    if myPath == newChangeParent {
      insert(fileChange: newChange)
    }
    else {
      let subpath = newChange.path.removingPrefix(myPath).removingPrefix("/")
      guard let parentName = subpath.firstPathComponent
      else { return }
      
      if let parentNode = children?.first(where: {
        $0.fileChange.path.removingPrefix(myPath)
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
