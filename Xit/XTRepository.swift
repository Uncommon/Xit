import Foundation


protocol RepositoryType {
  func commit(forSHA sha: String) -> CommitType?
}


/// Stores a repo reference for C callbacks
struct CallbackPayload { let repo: XTRepository }


extension XTRepository: RepositoryType {
  
  func commit(forSHA sha: String) -> CommitType?
  {
    return XTCommit(sha: sha, repository: self)
  }
}


extension XTRepository {
  
  func rebuildRefsIndex()
  {
    var payload = CallbackPayload(repo: self)
    var callback: git_reference_foreach_cb = { (reference, payload) -> Int32 in
      let repo = UnsafePointer<CallbackPayload>(payload).memory.repo
      
      var rawName = git_reference_name(reference)
      guard rawName != nil
      else { return 0 }
      var name = String(rawName)
      
      var resolved: COpaquePointer = nil
      guard git_reference_resolve(&resolved, reference) == 0
      else { return 0 }
      defer { git_reference_free(resolved) }
      
      let target = git_reference_target(resolved)
      guard target != nil
      else { return 0 }
      
      let sha = GTOID(gitOid: target).SHA
      var refs = repo.refsIndex[sha] ?? [String]()
      
      refs.append(name)
      repo.refsIndex[sha] = refs
      
      return 0
    }
    
    refsIndex.removeAll()
    git_reference_foreach(gtRepo.git_repository(), callback, &payload)
  }
  
  func refsAtCommit(sha: String) -> [String]
  {
    return refsIndex[sha] ?? []
  }
}
