import Foundation


@objc protocol RepositoryType {
  func commit(forSHA sha: String) -> CommitType?
  func commit(forOID oid: GTOID) -> CommitType?
}


/// Stores a repo reference for C callbacks
struct CallbackPayload { let repo: XTRepository }


extension XTRepository: RepositoryType {
  
  func commit(forSHA sha: String) -> CommitType?
  {
    return XTCommit(sha: sha, repository: self)
  }
  
  func commit(forOID oid: GTOID) -> CommitType?
  {
    return XTCommit(oid: oid, repository: self)
  }
}


extension XTRepository {
  
  func rebuildRefsIndex()
  {
    var payload = CallbackPayload(repo: self)
    var callback: git_reference_foreach_cb = { (reference, payload) -> Int32 in
      let repo = UnsafePointer<CallbackPayload>(payload).memory.repo
      
      var rawName = git_reference_name(reference)
      guard rawName != nil,
            let name = String.fromCString(rawName)
      else { return 0 }
      
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
  
  /// Returns a list of refs that point to the given commit.
  func refsAtCommit(sha: String) -> [String]
  {
    return refsIndex[sha] ?? []
  }
  
  /// Returns a list of all ref names.
  func allRefs() -> [String]
  {
    var stringArray = git_strarray()
    guard git_reference_list(&stringArray, gtRepo.git_repository()) == 0
    else { return [] }
    defer { git_strarray_free(&stringArray) }
    
    var result = [String]()
    
    for i in 0..<stringArray.count {
      guard let refString =
          String(UTF8String: UnsafePointer<CChar>(stringArray.strings[i]))
      else { continue }
      result.append(refString)
    }
    return result
  }

  func stashes() -> [XTStash]
  {
    var stashes = [XTStash]()
    
    // All we really need is the number of stashes,
    // but there is no call that does that.
    gtRepo.enumerateStashesUsingBlock { (index, message, oid, stop) in
      stashes.append(XTStash(repo: self, index: index, message: message))
    }
    return stashes
  }
  
  func submodules() -> [XTSubmodule]
  {
    var submodules = [XTSubmodule]()
    
    gtRepo.enumerateSubmodulesRecursively(false) {
      (submodule, error, stop) in
      if let submodule = submodule {
        submodules.append(XTSubmodule(repository: self, submodule: submodule))
      }
    }
    return submodules
  }
  
  /// Returns the list of tags, or throws if libgit2 hit an error.
  func tags() throws -> [XTTag]
  {
    let tags = try gtRepo.allTags()
    
    return tags.map({ XTTag(repository: self, tag: $0) })
  }
}
