import Foundation

extension XTRepository
{
  func createTag(name: String, targetOID: OID, message: String?) throws
  {
    try performWriting {
      guard let commit = GitCommit(oid: targetOID,
                                  repository: gitRepo)
      else { throw Error.notFound }
      
      let oid = UnsafeMutablePointer<git_oid>.allocate(capacity: 1)
      let signature = UnsafeMutablePointer<UnsafeMutablePointer<git_signature>?>
            .allocate(capacity: 1)
      let sigResult = git_signature_default(signature, gitRepo)
      
      try Error.throwIfError(sigResult)
      guard let finalSig = signature.pointee
      else { throw Error.unexpected }
      
      let result = git_tag_create(oid, gitRepo, name,
                                  commit.commit, finalSig, message, 0)
      
      try Error.throwIfError(result)
    }
  }
  
  func createLightweightTag(name: String, targetOID: OID) throws
  {
    try performWriting {
      guard let commit = GitCommit(oid: targetOID,
                                  repository: gitRepo)
      else { throw Error.notFound }
      
      let oid = UnsafeMutablePointer<git_oid>.allocate(capacity: 1)
      let result = git_tag_create_lightweight(oid, gitRepo, name,
                                              commit.commit, 0)
      
      try Error.throwIfError(result)
    }
  }
  
  func deleteTag(name: String) throws
  {
    try performWriting {
      let result = git_tag_delete(gitRepo, name)
      
      guard result == 0
      else {
        throw NSError.git_error(for: result)
      }
    }
  }
  
  func push(remote: String) throws
  {
    _ = try executeGit(args: ["push", "--all", remote], writes: true)
  }
  
  func moveHead(to refName: String) throws
  {
    let result = git_repository_set_head(gitRepo, refName)
    
    try Error.throwIfError(result)
  }
  
  private func checkout(object: OpaquePointer) throws
  {
    var options = git_checkout_options.defaultOptions(
          strategy: GIT_CHECKOUT_SAFE)
    let result = git_checkout_tree(gitRepo, object, &options)
    
    try Error.throwIfError(result)
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
  public func checkout(branch: String) throws
  {
    try performWriting {
      // invalidate ref caches
      
      let branchRef = BranchPrefixes.heads.appending(pathComponent: branch)
      
      try checkOut(refName: branchRef)
      try moveHead(to: branchRef)
    }
  }
  
  public func checkOut(refName: String) throws
  {
    guard let ref = reference(named: refName),
          let oid = ref.targetOID as? GitOID
    else { throw Error.notFound }
    
    let target = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
    let targetResult = git_object_lookup(target, gitRepo, oid.unsafeOID(),
                                         GIT_OBJ_ANY)
    guard targetResult == 0,
          let finalTarget = target.pointee
    else { throw Error.notFound }
    
    try checkout(object: finalTarget)
  }
  
  public func checkout(sha: String) throws
  {
    guard let oid = GitOID(sha: sha)
    else { throw Error.notFound }
    let object = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
    let lookupResult = git_object_lookup_prefix(object, gitRepo, oid.unsafeOID(),
                                                Int(GIT_OID_RAWSZ), GIT_OBJ_ANY)
    guard lookupResult == 0,
          let finalObject = object.pointee
    else { throw Error.notFound }
    
    try checkout(object: finalObject)
  }
}

extension XTRepository: Stashing
{
  // TODO: Don't require the message parameter
  public func stash(index: UInt, message: String?) -> Stash
  {
    return XTStash(repo: self, index: index, message: message)
  }
  
  @objc(saveStash:includeUntracked:error:)
  func saveStash(name: String?, includeUntracked: Bool) throws
  {
    var args = ["stash", "save"]
    
    if includeUntracked {
      args.append("--include-untracked")
    }
    if let name = name {
      args.append(name)
    }
    _ = try executeGit(args: args, writes: true)
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
      
      try Error.throwIfError(result)
    }
  }
  
  public func applyStash(index: UInt) throws
  {
    var applyOptions = stashApplyOptions()
    
    try performWriting {
      let result = git_stash_apply(gitRepo, Int(index), &applyOptions)
      
      try Error.throwIfError(result)
    }
  }
  
  public func dropStash(index: UInt) throws
  {
    try performWriting {
      let result = git_stash_drop(gitRepo, Int(index))
      
      try Error.throwIfError(result)
    }
  }
  
  public func commitForStash(at index: UInt) -> Commit?
  {
    guard let stashRef = try? gtRepo.lookUpReference(withName: "refs/stash"),
          let stashLog = GTReflog(reference: stashRef),
          index < stashLog.entryCount,
          let entry = stashLog.entry(at: index),
          let oid = entry.updatedOID.map({ GitOID(oid: $0.git_oid().pointee) })
    else { return nil }
    
    return GitCommit(oid: oid, repository: gitRepo)
  }
}

extension XTRepository: RemoteManagement
{
  public func remote(named name: String) -> Remote?
  {
    return GitRemote(name: name, repository: gitRepo)
  }
  
  public func addRemote(named name: String, url: URL) throws
  {
    _ = try executeGit(args: ["remote", "add", name, url.absoluteString],
                       writes: true)
  }
  
  public func deleteRemote(named name: String) throws
  {
    _ = try executeGit(args: ["remote", "rm", name],
                       writes: true)
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
