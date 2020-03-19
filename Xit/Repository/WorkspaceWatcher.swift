import Foundation


class WorkspaceWatcher: NSObject
{
  weak var controller: RepositoryController?
  private(set) var stream: FileEventStream! = nil
  var skipIgnored = true
  
  init?(controller: RepositoryController)
  {
    self.controller = controller
    super.init()
    
    guard let repository = controller.repository as? XTRepository,
          let stream = FileEventStream(
        path: repository.repoURL.path,
        excludePaths: [repository.gitDirectoryPath],
        queue: controller.queue.queue,
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
    guard let controller = self.controller,
          let repository = controller.repository as? FileStatusDetection
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
      controller.invalidateIndex()
      NotificationCenter.default.post(name: .XTRepositoryWorkspaceChanged,
                                      object: controller.repository,
                                      userInfo: userInfo)
    }
  }
}
