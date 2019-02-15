import Foundation


@objc(XTWorkspaceWatcher)
class WorkspaceWatcher: NSObject
{
  weak var repository: XTRepository?
  private(set) var stream: FileEventStream! = nil
  var skipIgnored = true
  
  init?(repository: XTRepository)
  {
    self.repository = repository
    super.init()
    
    guard let stream = FileEventStream(
        path: repository.repoURL.path,
        excludePaths: [repository.gitDirectoryPath],
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
    guard let repository = self.repository
    else { return }
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
      repository.invalidateIndex()
      NotificationCenter.default.post(name: .XTRepositoryWorkspaceChanged,
                                      object: repository,
                                      userInfo: userInfo)
    }
  }
}
