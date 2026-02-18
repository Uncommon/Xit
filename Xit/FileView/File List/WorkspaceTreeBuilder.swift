import Cocoa
import XitGit

final class WorkspaceTreeBuilder
{
  private var changes: [String: DeltaStatus]
  private var repo: (any FileStatusDetection)?
  
  init(changes: [String: DeltaStatus])
  {
    self.changes = changes
  }
  
  init(fileChanges: [FileChange], repo: (any FileStatusDetection)? = nil)
  {
    var changes = [String: DeltaStatus]()
    
    for change in fileChanges {
      changes[change.path] = change.status
    }
    self.changes = changes
    self.repo = repo
  }
  
  func treeAtURL(_ baseURL: URL, rootPath: NSString) -> FileChangeNode
  {
    let myPath = baseURL.path.droppingPrefix(rootPath as String).nilIfEmpty ??
                 FileChangeNode.rootName + "/"
    let rootItem = FileChange(path: myPath)
    let node = FileChangeNode(value: rootItem)
    let enumerator = FileManager.default.enumerator(
          at: baseURL,
          includingPropertiesForKeys: [ URLResourceKey.isDirectoryKey ],
          options: .skipsSubdirectoryDescendants,
          errorHandler: nil)
    let rootPathLength = rootPath.length
    
    while let url: URL = enumerator?.nextObject() as! URL? {
      let urlPath = url.path
      let relativePath = (urlPath as NSString).substring(from: rootPathLength)
      guard relativePath != "/.git",
            !(repo?.isIgnored(path: relativePath) ?? false)
      else { continue }
      let path = FileChangeNode.rootName
                               .appending(pathComponent: relativePath)

      var childNode: FileChangeNode?
      var isDirectory: AnyObject?
      
      do {
        try (url as NSURL).getResourceValue(&isDirectory,
                                            forKey: URLResourceKey.isDirectoryKey)
      }
      catch {
        continue
      }
      if let isDirValue = isDirectory as? NSNumber {
        if isDirValue.boolValue {
          childNode = self.treeAtURL(url, rootPath: rootPath)
        }
        else {
          var item = FileChange(path: path)

          if let status = self.changes[relativePath.droppingPrefix("/")] {
            item.status = status
          }
          childNode = FileChangeNode(value: item)
        }
      }
      childNode.map { node.children.append($0) }
    }
    return node
  }
  
  func build(_ baseURL: URL) -> FileChangeNode
  {
    return self.treeAtURL(baseURL, rootPath: baseURL.path as NSString)
  }
}
