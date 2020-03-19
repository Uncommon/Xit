import Foundation

extension XTRepository: CommitStorage
{
  public func oid(forSHA sha: String) -> OID?
  {
    return GitOID(sha: sha)
  }
  
  public func commit(forSHA sha: String) -> Commit?
  {
    return GitCommit(sha: sha, repository: gitRepo)
  }
  
  public func commit(forOID oid: OID) -> Commit?
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
  
  public func walker() -> RevWalk?
  {
    return GitRevWalk(repository: gitRepo)
  }
}

extension XTRepository: CommitReferencing
{
  var headReference: Reference?
  {
    return GitReference(headForRepo: gitRepo)
  }
  
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
  public func refs(at sha: String) -> [String]
  {
    objc_sync_enter(self)
    defer {
      objc_sync_exit(self)
    }
    return refsIndex[sha] ?? []
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
  
  var headSHA: String?
  {
    return headRef.map { sha(forRef: $0) } ?? nil
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
  
  public func oid(forRef ref: String) -> OID?
  {
    var object: OpaquePointer? = nil
    let result = git_revparse_single(&object, gitRepo, ref)
    guard result == 0,
          let finalObject = object,
          let oid = git_object_id(finalObject)
    else { return nil }
    
    return GitOID(oidPtr: oid)
  }
  
  func createBranch(_ name: String) -> Bool
  {
    clearCachedBranch()
    return (try? executeGit(args: ["checkout", "-b", name],
                            writes: true)) != nil
  }
  
  func deleteBranch(_ name: String) -> Bool
  {
    return writing {
      guard let branch = localBranch(named: name) as? GitLocalBranch
      else { return false }
      
      return git_branch_delete(branch.branchRef) == 0
    }
  }
  
  /// Returns the list of tags, or throws if libgit2 hit an error.
  public func tags() throws -> [Tag]
  {
    var tagNames = git_strarray()
    let result = git_tag_list(&tagNames, gitRepo)
    
    try RepoError.throwIfGitError(result)
    defer { git_strarray_free(&tagNames) }
    
    return tagNames.compactMap {
      name in name.flatMap { GitTag(repository: self, name: $0) }
    }
  }
  
  public func reference(named name: String) -> Reference?
  {
    return GitReference(name: name, repository: gitRepo)
  }
  
  public func createCommit(with tree: Tree, message: String, parents: [Commit],
                           updatingReference refName: String) throws -> OID
  {
    var commitPtrs: [OpaquePointer?] =
      parents.compactMap { ($0 as? GitCommit)?.commit }
    guard commitPtrs.count == parents.count,
      let gitTree = tree as? GitTree
      else { throw RepoError.unexpected }
    
    let signature = GitSignature(defaultFromRepo: gitRepo)
    var newOID = git_oid()
    let result = git_commit_create(&newOID, gitRepo, refName,
                                   signature?.signature, signature?.signature,
                                   "UTF-8", message, gitTree.tree,
                                   parents.count, &commitPtrs)
    
    try RepoError.throwIfGitError(result)
    return GitOID(oid: newOID)
  }
}
