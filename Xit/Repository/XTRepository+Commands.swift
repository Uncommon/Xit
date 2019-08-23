import Foundation

extension XTRepository
{
  func push(remote: String) throws
  {
    _ = try executeGit(args: ["push", "--all", remote], writes: true)
  }
  
  func moveHead(to refName: String) throws
  {
    let result = git_repository_set_head(gitRepo, refName)
    
    try RepoError.throwIfGitError(result)
  }
  
  private func checkout(object: OpaquePointer) throws
  {
    var options = git_checkout_options.defaultOptions(
          strategy: GIT_CHECKOUT_SAFE)
    let result = git_checkout_tree(gitRepo, object, &options)
    
    try RepoError.throwIfGitError(result)
  }
  
  func stagePatch(_ patch: String) throws
  {
    _ = try executeGit(args: ["apply", "--cached"], stdIn: patch, writes: true)
  }
  
  func unstagePatch(_ patch: String) throws
  {
    _ = try executeGit(args: ["apply", "--cached", "--reverse"],
                       stdIn: patch,
                       writes: true)
  }
  
  func discardPatch(_ patch: String) throws
  {
    _ = try executeGit(args: ["apply", "--reverse"],
                       stdIn: patch,
                       writes: true)
  }
  
  func renameRemote(old: String, new: String) throws
  {
    _ = try executeGit(args: ["remote", "rename", old, new], writes: true)
  }
}

extension XTRepository: Workspace
{
  public func checkOut(branch: String) throws
  {
    try performWriting {
      // invalidate ref caches
      
      let branchRef = RefPrefixes.heads.appending(pathComponent: branch)
      
      try checkOut(refName: branchRef)
      try moveHead(to: branchRef)
    }
  }
  
  public func checkOut(refName: String) throws
  {
    guard let ref = reference(named: refName),
          let oid = ref.targetOID as? GitOID
    else { throw RepoError.notFound }
    
    let target = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
    let targetResult = git_object_lookup(target, gitRepo, oid.unsafeOID(),
                                         GIT_OBJECT_ANY)
    guard targetResult == 0,
          let finalTarget = target.pointee
    else { throw RepoError.notFound }
    
    try checkout(object: finalTarget)
  }
  
  public func checkOut(sha: String) throws
  {
    guard let oid = GitOID(sha: sha)
    else { throw RepoError.notFound }
    let object = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
    let lookupResult = git_object_lookup_prefix(object, gitRepo, oid.unsafeOID(),
                                                Int(GIT_OID_RAWSZ),
                                                GIT_OBJECT_ANY)
    guard lookupResult == 0,
          let finalObject = object.pointee
    else { throw RepoError.notFound }
    
    try checkout(object: finalObject)
  }
}

extension XTRepository: Stashing
{
  public var stashes: AnyCollection<Stash>
  {
    return AnyCollection(StashCollection(repo: self))
  }
  
  // TODO: Don't require the message parameter
  public func stash(index: UInt, message: String?) -> Stash
  {
    return GitStash(repo: self, index: index, message: message)
  }
  
  public func saveStash(name: String?,
                        keepIndex: Bool,
                        includeUntracked: Bool,
                        includeIgnored: Bool) throws
  {
    guard !isWriting
    else { throw RepoError.alreadyWriting }
    
    let flags = (keepIndex ? GIT_STASH_KEEP_INDEX.rawValue : 0) +
                (includeUntracked ? GIT_STASH_INCLUDE_UNTRACKED.rawValue : 0) +
                (includeIgnored ? GIT_STASH_INCLUDE_IGNORED.rawValue : 0)
    var oid = git_oid()
    
    guard let signature = GitSignature(defaultFromRepo: gitRepo)
    else { throw RepoError.unexpected }
    
    let result = git_stash_save(&oid, gitRepo, signature.signature,
                                name, flags)
    
    try RepoError.throwIfGitError(result)
  }
  
  func stashApplyOptions() -> git_stash_apply_options
  {
    var applyOptions = git_stash_apply_options.defaultOptions()
    
    applyOptions.flags = GIT_STASH_APPLY_REINSTATE_INDEX
    applyOptions.checkout_options = git_checkout_options.defaultOptions()
    applyOptions.checkout_options.checkout_strategy = GIT_CHECKOUT_SAFE.rawValue
    
    // potentially add a progress callback

    return applyOptions
  }
  
  public func popStash(index: UInt) throws
  {
    var applyOptions = stashApplyOptions()
    
    try performWriting {
      let result = git_stash_pop(gitRepo, Int(index), &applyOptions)
      
      try RepoError.throwIfGitError(result)
    }
  }
  
  public func applyStash(index: UInt) throws
  {
    var applyOptions = stashApplyOptions()
    
    try performWriting {
      let result = git_stash_apply(gitRepo, Int(index), &applyOptions)
      
      try RepoError.throwIfGitError(result)
    }
  }
  
  public func dropStash(index: UInt) throws
  {
    try performWriting {
      let result = git_stash_drop(gitRepo, Int(index))
      
      try RepoError.throwIfGitError(result)
    }
  }
  
  public func commitForStash(at index: UInt) -> Commit?
  {
    guard let stashLog = GitRefLog(repository: gitRepo, refName: "refs/stash"),
          index < stashLog.entryCount
    else { return nil }
    let entry = stashLog.entry(atIndex: Int(index))

    return GitCommit(oid: entry.newOID, repository: gitRepo)
  }
}

extension XTRepository: RemoteManagement
{
  public func remoteNames() -> [String]
  {
    let strArray = UnsafeMutablePointer<git_strarray>.allocate(capacity: 1)
    guard git_remote_list(strArray, gitRepo) == 0
    else { return [] }
    
    return strArray.pointee.compactMap { $0 }
  }
  
  public func remote(named name: String) -> Remote?
  {
    return GitRemote(name: name, repository: gitRepo)
  }
  
  public func addRemote(named name: String, url: URL) throws
  {
    try performWriting {
      let remote = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
      let result = git_remote_create(remote, gitRepo, name, url.absoluteString)
      
      try RepoError.throwIfGitError(result)
    }
  }
  
  public func deleteRemote(named name: String) throws
  {
    try performWriting {
      let result = git_remote_delete(gitRepo, name)
      
      try RepoError.throwIfGitError(result)
    }
  }
}

extension XTRepository: SubmoduleManagement
{
  public func addSubmodule(path: String, url: String) throws
  {
    _ = try executeGit(args: ["submodule", "add", "-f", url, path],
                       writes: true)
    /* still needs clone
    _ = try performWriting {
     git_submodule *gitSub = NULL;
     let result = git_submodule_add_setup(
        &gitSub, gitRepo,
        [urlOrPath UTF8String], [path UTF8String], false);
     
     if ((result != 0) && (error != NULL)) {
      *error = [NSError git_errorFor:result];
      return NO;
     }
     // clone the sub-repo
     git_submodule_add_finalize(gitSub);
    }
    */
  }
  
  public func submodules() -> [Submodule]
  {
    class Payload { var submodules = [Submodule]() }
    
    var payload = Payload()
    let callback: git_submodule_cb = {
      (submodule, name, payload) in
      guard let submodule = submodule,
            let repo = git_submodule_owner(submodule)
      else { return 0 }
      let payload = payload!.bindMemory(to: Payload.self, capacity: 1)
      
      // Look it up again to get an owned reference
      let mySubmodule = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
      let lookup = git_submodule_lookup(mySubmodule, repo,
                                        git_submodule_name(submodule))
      guard lookup == 0,
            let finalSubmodule = mySubmodule.pointee
      else { return 0 }
      
      payload.pointee.submodules.append(GitSubmodule(submodule: finalSubmodule))
      return 0
    }
    
    git_submodule_foreach(gitRepo, callback, &payload)
    return payload.submodules
  }
}
