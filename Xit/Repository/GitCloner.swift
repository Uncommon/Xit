import Foundation

public final class GitCloner: Cloning
{
  @discardableResult
  public func clone(from source: URL, to destination: URL,
                    branch: String,
                    recurseSubmodules: Bool,
                    passwordStorage: any PasswordStorage,
                    publisher: RemoteProgressPublisher) throws
    -> (any FullRepository)?
  {
    try branch.withCString {
      (cBranch) in
      let callbacks = RemoteCallbacks(copying: publisher.callbacks)

      callbacks.passwordStorage = passwordStorage
      return try git_remote_callbacks.withCallbacks(callbacks) {
        (gitCallbacks) in
        var options = git_clone_options.defaultOptions()
        
        options.bare = 0
        options.checkout_branch = cBranch
        options.fetch_opts.callbacks = gitCallbacks
        
        let gitRepo: OpaquePointer
        
        do {
          gitRepo = try OpaquePointer.from {
            git_clone(&$0, source.absoluteString, destination.path, &options)
          }
        }
        catch let error as RepoError {
          publisher.error(error)
          throw error
        }
        catch let error  {
          publisher.error(.unexpected)
          throw error
        }
        guard let repo = try? XTRepository(gitRepo: gitRepo)
        else { return nil }

        if recurseSubmodules {
          for sub in repo.submodules() {
            try sub.update(callbacks: publisher.callbacks)
            // recurse
          }
        }
        
        publisher.finished()
        return repo
      }
    }
  }
}
