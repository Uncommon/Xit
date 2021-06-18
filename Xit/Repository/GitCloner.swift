import Foundation

public class GitCloner: Cloning
{
  @discardableResult
  public func clone(from source: URL, to destination: URL,
                    branch: String,
                    recurseSubmodules: Bool,
                    callbacks: RemoteCallbacks) throws -> Repository?
  {
    var options = git_clone_options.defaultOptions()
    
    return try branch.withCString {
      (cBranch) in
      try git_remote_callbacks.withCallbacks(callbacks) {
        (gitCallbacks) in
        options.bare = 0
        options.checkout_branch = cBranch
        options.fetch_opts.callbacks = gitCallbacks
        
        let gitRepo = try OpaquePointer.from {
          git_clone(&$0, source.absoluteString, destination.path, &options)
        }
        guard let repo = XTRepository(gitRepo: gitRepo)
        else { return nil}

        if recurseSubmodules {
          for sub in repo.submodules() {
            try sub.update(callbacks: callbacks)
            // recurse
          }
        }
        
        return repo
      }
    }
  }
}
