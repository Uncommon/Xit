import Foundation
import Clibgit2

extension XTRepository: CommitStorage
{
  public func commit(forSHA sha: SHA) -> GitCommit?
  {
    return GitCommit(sha: sha, repository: gitRepo)
  }
  
  public func commit(forOID oid: GitOID) -> GitCommit?
  {
    return GitCommit(oid: oid, repository: gitRepo)
  }
  
  public func commit(message: String, amend: Bool) throws
  {
    if amend { // git_commit_create_from_stage doesn't support amend
      _ = try executeGit(args: ["commit", "-F", "--amend", "-"],
                         stdIn: message, writes: true)
      invalidateIndex()
    }
    else {
      try writing {
        var options = git_commit_create_options.defaultOptions()
        guard let signature = GitSignature(defaultFromRepo: gitRepo)
        else { throw RepoError.unexpected }

        // git_commit_create_from_stage() has a bug where it crashes if author
        // and committer are both null.
        try withUnsafePointer(to: &signature.signature.pointee) { sig in
          options.author = sig
          options.committer = sig

          var commitOID: git_oid = .init()
          let result = git_commit_create_from_stage(&commitOID,
                                                    gitRepo, message, &options)

          try RepoError.throwIfGitError(result)
          invalidateIndex()
        }
      }
    }
  }
  
  public func walker() -> GitRevWalk?
  {
    GitRevWalk(repository: gitRepo)
  }
}

extension XTRepository: CommitReferencing
{
  var headReference: (any Reference)?
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
    withUnsafeMutablePointer(to: &payload) {
      _ = git_reference_foreach(gitRepo, callback, $0)
    }
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
  public func allRefs() -> [GeneralRefName]
  {
    var stringArray = git_strarray()
    guard git_reference_list(&stringArray, gitRepo) == 0
    else { return [] }
    defer { git_strarray_free(&stringArray) }
    
    return stringArray.compactMap { $0.flatMap { .init(rawValue: $0) } }
  }
  
  public var headRefName: (any ReferenceName)?
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
  
  func calculateCurrentBranch() -> LocalBranchRefName?
  {
    guard let name = headReference?.resolve()?.name
    else {
      return nil
    }
    return name as? LocalBranchRefName
  }

  func hasHeadReference() -> Bool
  {
    return headReference != nil
  }
  
  public func parentTree() -> String
  {
    return hasHeadReference() ? "HEAD" : SHA.emptyTree.rawValue
  }
  
  public func sha(forRef ref: any ReferenceName) -> SHA?
  {
    return oid(forRef: ref)?.sha
  }
  
  public func oid(forRef ref: any ReferenceName) -> GitOID?
  {
    guard let object = try? OpaquePointer.from({
            git_revparse_single(&$0, gitRepo, ref.fullPath)
          })
    else { return nil }
    defer {
      git_object_free(object)
    }
    guard let oid = git_object_id(object)
    else { return nil }
    
    return GitOID(oidPtr: oid)
  }
  
  public func deleteBranch(_ name: String) throws
  {
    return try writing {
      guard let refName = LocalBranchRefName(name),
            let branch = localBranch(named: refName)
      else { throw RepoError.notFound }

      try RepoError.throwIfGitError(git_branch_delete(branch.branchRef))
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
  
  public func reference(named name: String) -> (any Reference)?
  {
    return GitReference(name: name, repository: gitRepo)
  }
  
  public func createCommit(with tree: GitTree, message: String,
                           parents: [GitCommit],
                           updatingReference refName: String) throws -> GitOID
  {
    var commitPtrs: [OpaquePointer?] = parents.compactMap { $0.commit }
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
