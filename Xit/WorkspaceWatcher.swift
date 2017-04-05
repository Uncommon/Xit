import Foundation


@objc(XTWorkspaceWatcher)
class WorkspaceWatcher: NSObject
{
  unowned let repository: XTRepository
  var stream: FileEventStream! = nil
  
  init?(repository: XTRepository)
  {
    self.repository = repository
    super.init()
    
    guard let stream = FileEventStream(
        path: repository.repoURL.path,
        excludePaths: [repository.gitDirectoryURL.path],
        queue: repository.queue,
        callback: { [weak self] (paths) in self?.observeEvents(paths) })
    else { return nil }
    
    self.stream = stream
  }
  
  func stop()
  {
    self.stream.stop()
  }
  
  func observeEvents(_ paths: [String])
  {
    NotificationCenter.default.post(
        name: NSNotification.Name.XTRepositoryWorkspaceChanged,
        object: repository,
        userInfo: [XTPathsKey: paths])
  }
}
