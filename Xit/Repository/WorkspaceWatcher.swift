import Foundation
import Combine

final class WorkspaceWatcher
{
  weak var controller: (any RepositoryController)?
  private(set) var stream: FileEventStream! = nil
  var skipIgnored = true

  private let subject = PassthroughSubject<[String], Never>()
  var publisher: AnyPublisher<[String], Never> { subject.eraseToAnyPublisher() }
  
  init?(controller: any RepositoryController)
  {
    self.controller = controller
    
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
    let changedPaths: [String]
  
    if skipIgnored {
      let filteredPaths = paths.filter { !repository.isIgnored(path: $0) }
      guard !filteredPaths.isEmpty
      else { return }
      
      changedPaths = filteredPaths
    }
    else {
      changedPaths = paths
    }
  
    self.subject.send(changedPaths)
  }
}
