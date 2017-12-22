import Foundation

extension XTRepository
{
  func createTag(name: String, targetOID: OID, message: String?) throws
  {
    try performWriting {
      guard let commit = XTCommit(oid: targetOID,
                                  repository: gtRepo.git_repository())
      else { throw Error.notFound }
      
      let oid = UnsafeMutablePointer<git_oid>.allocate(capacity: 1)
      let signature = UnsafeMutablePointer<UnsafeMutablePointer<git_signature>?>
            .allocate(capacity: 1)
      let sigResult = git_signature_default(signature, gtRepo.git_repository())
      
      try Error.throwIfError(sigResult)
      guard let finalSig = signature.pointee
      else { throw Error.unexpected }
      
      let result = git_tag_create(oid, gtRepo.git_repository(), name,
                                  commit.commit, finalSig, message, 0)
      
      try Error.throwIfError(result)
    }
  }
  
  func createLightweightTag(name: String, targetOID: OID) throws
  {
    try performWriting {
      guard let commit = XTCommit(oid: targetOID,
                                  repository: gtRepo.git_repository())
      else { throw Error.notFound }
      
      let oid = UnsafeMutablePointer<git_oid>.allocate(capacity: 1)
      let result = git_tag_create_lightweight(oid, gtRepo.git_repository(), name,
                                              commit.commit, 0)
      
      try Error.throwIfError(result)
    }
  }
  
  func deleteTag(name: String) throws
  {
    try performWriting {
      let result = git_tag_delete(gtRepo.git_repository(), name)
      
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
  
  func checkout(branch: String) throws
  {
    try performWriting {
      // invalidate ref caches
      
      let branchRef = BranchPrefixes.heads.appending(pathComponent: branch)
      let ref = try gtRepo.lookUpReference(withName: branchRef)
      let options = GTCheckoutOptions(strategy: [.safe])
      
      try gtRepo.checkoutReference(ref, options: options)
    }
  }
  
  func checkout(sha: String) throws
  {
    guard let commit = try gtRepo.lookUpObject(bySHA: sha) as? GTCommit
    else { throw Error.unexpected }
    let options = GTCheckoutOptions(strategy: [.safe])
    
    try gtRepo.checkoutCommit(commit, options: options)
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
  
  func unstageAllFiles() throws
  {
    guard let index = GitIndex(repository: self)
    else { throw Error.unexpected }
    
    if let headOID = headReference?.resolve()?.targetOID {
      guard let headCommit = commit(forOID: headOID),
            let headTree = headCommit.tree
      else { throw Error.unexpected }
      
      try index.read(tree: headTree)
    }
    else {
      // If there is no head, then this is the first commit
      try index.clear()
    }

    try index.save()
  }
  
  func renameRemote(old: String, new: String) throws
  {
    _ = try executeGit(args: ["remote", "rename", old, new], writes: true)
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
    _ = try executeGit(args: args, stdIn: nil, writes: true)
  }
  
  func stashCheckoutOptions() -> GTCheckoutOptions
  {
    return GTCheckoutOptions(strategy: .safe)
  }
  
  public func popStash(index: UInt) throws
  {
    _ = try performWriting {
      try gtRepo.popStash(at: index, flags: [.reinstateIndex],
                          checkoutOptions: stashCheckoutOptions(),
                          progressBlock: nil)
    }
  }
  
  public func applyStash(index: UInt) throws
  {
    _ = try performWriting {
      try gtRepo.applyStash(at: index, flags: [.reinstateIndex],
                            checkoutOptions: stashCheckoutOptions(),
                            progressBlock: nil)
    }
  }
  
  public func dropStash(index: UInt) throws
  {
    _ = try performWriting {
      try gtRepo.dropStash(at: index)
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
    
    return XTCommit(oid: oid, repository: gtRepo.git_repository())
  }
}

extension XTRepository: RemoteManagement
{
  public func remote(named name: String) -> Remote?
  {
    return GitRemote(name: name, repository: gtRepo.git_repository())
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
        &gitSub, [gtRepo git_repository],
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
    
    git_submodule_foreach(gtRepo.git_repository(), callback, &payload)
    return payload.submodules
  }
}
