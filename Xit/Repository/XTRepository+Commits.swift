import Foundation

extension XTRepository: CommitStorage
{
  public func oid(forSHA sha: String) -> GitOID?
  {
    return GitOID(sha: sha)
  }
  
  public func commit(forSHA sha: String) -> GitCommit?
  {
    return GitCommit(sha: sha, repository: gitRepo)
  }
  
  public func commit(forOID oid: GitOID) -> GitCommit?
  {
    return GitCommit(oid: oid, repository: gitRepo)
  }
  
  public func commit(message: String, amend: Bool) throws
  {
    let baseArgs = ["commit", "-F", "-"]
    let args = amend ? baseArgs + ["--amend"] : baseArgs
    
    _ = try executeGit(args: args, stdIn: message, writes: true)
    invalidateIndex()
  }
  
  public func walker() -> (any RevWalk)?
  {
    return GitRevWalk(repository: gitRepo)
  }
}

extension XTRepository: CommitReferencing
{
  var headReference: GitReference?
  { GitReference(headForRepo: gitRepo) }
  
  /// Reloads the cached map of OIDs to refs.
  public func rebuildRefsIndex()
  {
    var payload = CallbackPayload(repo: self)
    let callback: git_reference_foreach_cb = {
      (reference, payload) -> Int32 in
      defer {
        git_reference_free(reference)
      }
      
      let repo = payload!.bindMemory(to: XTRepository.self,
                                     capacity: 1).pointee
      
      guard let rawName = git_reference_name(reference),
            let name = String(validatingUTF8: rawName)
      else { return 0 }
      
      var peeled: OpaquePointer?
      guard git_reference_peel(&peeled, reference, GIT_OBJECT_COMMIT) == 0
      else { return 0 }
      
      let peeledOID = git_object_id(peeled)
      guard let sha = peeledOID.map({ GitOID(oid: $0.pointee) })?.sha
      else { return 0 }
      var refs = repo.refsIndex[sha] ?? [String]()
      
      refs.append(name)
      repo.refsIndex[sha] = refs
      
      return 0
    }
    
    objc_sync_enter(self)
    defer {
      objc_sync_exit(self)
    }
    refsIndex.removeAll()
    git_reference_foreach(gitRepo, callback, &payload)
  }
  
  /// Returns a list of refs that point to the given commit.
  public func refs(at oid: GitOID) -> [String]
  {
    objc_sync_enter(self)
    defer {
      objc_sync_exit(self)
    }
    return refsIndex[oid.sha] ?? []
  }
  
  /// Returns a list of all ref names.
  public func allRefs() -> [String]
  {
    var stringArray = git_strarray()
    guard git_reference_list(&stringArray, gitRepo) == 0
    else { return [] }
    defer { git_strarray_free(&stringArray) }
    
    return stringArray.compactMap { $0 }
  }
  
  public var headRef: String?
  {
    objc_sync_enter(self)
    defer {
      objc_sync_exit(self)
    }
    if cachedHeadRef == nil {
      recalculateHead()
    }
    return cachedHeadRef
  }
  
  func calculateCurrentBranch() -> String?
  {
    return headReference?.resolve()?.name.droppingPrefix(RefPrefixes.heads)
  }
  
  func hasHeadReference() -> Bool
  {
    return headReference != nil
  }
  
  func parentTree() -> String
  {
    return hasHeadReference() ? "HEAD" : kEmptyTreeHash
  }
  
  public func sha(forRef ref: String) -> String?
  {
    return oid(forRef: ref)?.sha
  }
  
  public func oid(forRef ref: String) -> GitOID?
  {
    guard let object = try? OpaquePointer.from({
            git_revparse_single(&$0, gitRepo, ref)
          })
    else { return nil }
    defer {
      git_object_free(object)
    }
    guard let oid = git_object_id(object)
    else { return nil }
    
    return GitOID(oidPtr: oid)
  }
  
  func deleteBranch(_ name: String) -> Bool
  {
    return writing {
      guard let branch = localBranch(named: name)
      else { return false }
      
      return git_branch_delete(branch.branchRef) == 0
    }
  }
  
  /// Returns the list of tags, or throws if libgit2 hit an error.
  public func tags() throws -> [GitTag]
  {
    var tagNames = git_strarray()
    let result = git_tag_list(&tagNames, gitRepo)
    
    try RepoError.throwIfGitError(result)
    defer { git_strarray_free(&tagNames) }
    
    return tagNames.compactMap {
      name in name.flatMap { GitTag(repository: self, name: $0) }
    }
  }
  
  public func reference(named name: String) -> GitReference?
  {
    return GitReference(name: name, repository: gitRepo)
  }
  
  public func createCommit(with tree: GitTree, message: String,
                           parents: [GitCommit],
                           updatingReference refName: String) throws -> GitOID
  {
    var commitPtrs: [OpaquePointer?] = parents.map { $0.commit }
    guard commitPtrs.count == parents.count
    else { throw RepoError.unexpected }
    
    let signature = GitSignature(defaultFromRepo: gitRepo)
    var newOID = git_oid()
    let result = git_commit_create(&newOID, gitRepo, refName,
                                   signature?.signature, signature?.signature,
                                   "UTF-8", message, tree.tree,
                                   parents.count, &commitPtrs)
    
    try RepoError.throwIfGitError(result)
    return GitOID(oid: newOID)
  }
}
