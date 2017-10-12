import Foundation


@objc(XTWorkspaceWatcher)
class WorkspaceWatcher: NSObject
{
  unowned let repository: XTRepository
  private(set) var stream: FileEventStream! = nil
  var skipIgnored = true
  
  init?(repository: XTRepository)
  {
    self.repository = repository
    super.init()
    
    guard let stream = FileEventStream(
        path: repository.repoURL.path,
        excludePaths: [repository.gitDirectoryURL.path],
        queue: repository.queue.queue,
        callback: { [weak self] (paths) in self?.observeEvents(paths) })
    else { return nil }
    
    self.stream = stream
  }
  
  deinit
  {
    stop()
  }
  
  func stop()
  {
    stream.stop()
  }
  
  func observeEvents(_ paths: [String])
  {
    var userInfo = [String: Any]()
  
    if skipIgnored {
      let filteredPaths = paths.filter { !repository.isIgnored(path: $0) }
      guard !filteredPaths.isEmpty
      else { return }
      
      userInfo = [XTPathsKey: filteredPaths]
    }
    else {
      userInfo = [XTPathsKey: paths]
    }
  
    DispatchQueue.main.async {
      NotificationCenter.default.post(
          name: NSNotification.Name.XTRepositoryWorkspaceChanged,
          object: self.repository,
          userInfo: userInfo)
    }
  }
}
