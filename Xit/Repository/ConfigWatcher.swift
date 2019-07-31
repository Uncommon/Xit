import Foundation

/// Watches all files used to determine repository config settings.
class ConfigWatcher
{
  let repository: XTRepository
  private(set) var repoConfigStream: FileEventStream! = nil
  private(set) var userConfigStream: FileEventStream! = nil
  private(set) var globalConfigStream: FileEventStream! = nil
  
  init(repository: XTRepository)
  {
    self.repository = repository
    
    var pathBuf = git_buf()
    var result: Int32
    let callback = {
      [weak self]
      (paths: [String]) -> Void in
      self?.observeEvents(paths)
    }
    
    result = git_repository_item_path(&pathBuf, repository.gitRepo,
                                      GIT_REPOSITORY_ITEM_CONFIG)
    if result == 0 {
      let repoPath = String(cString: pathBuf.ptr)
      
      repoConfigStream = FileEventStream(path: repoPath,
                                         excludePaths: [],
                                         queue: .main,
                                         callback: callback)
    }
    userConfigStream = FileEventStream(path: "~/.gitconfig".expandingTildeInPath,
                                       excludePaths: [],
                                       queue: .main,
                                       callback: callback)
    globalConfigStream = FileEventStream(path: "/etc/gitconfig",
                                         excludePaths: [], queue: .main,
                                         callback: callback)
  }
  
  func stop()
  {
    repoConfigStream.stop()
    userConfigStream.stop()
    globalConfigStream.stop()
  }
  
  private func observeEvents(_ paths: [String])
  {
    repository.config.invalidate()
    DispatchQueue.main.async {
      [weak self] in
      guard let self = self
      else { return }
      
      NotificationCenter.default.post(name: .XTRepositoryConfigChanged,
                                      object: self.repository)
    }
  }
}
