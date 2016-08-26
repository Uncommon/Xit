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

extension XTRepository {  // MARK: Push/pull
  
  func credentialProvider(passwordBlock: () -> (String, String)?)
      -> GTCredentialProvider
  {
    return GTCredentialProvider() {
      (type, url, user) -> GTCredential in
      if checkCredentialType(type, flag: .SSHKey) {
        return sshCredential(user) ?? GTCredential()
      }
      
      guard checkCredentialType(type, flag: .UserPassPlaintext)
      else { return GTCredential() }
      
      if let password = keychainPassword(url, user: user) {
        do {
          return try GTCredential(userName: user, password: password)
        }
        catch let error as NSError {
          NSLog(error.description)
        }
      }
      
      if let (userName, password) = passwordBlock(),
         let result = try? GTCredential(userName: userName,
                                        password: password) {
        return result
      }
      return GTCredential()
    }
  }
  
  public func fetchOptions(downloadTags: Bool,
                           pruneBranches: Bool,
                           passwordBlock: () -> (String, String)?)
      -> [String: AnyObject]
  {
    let tagOption = downloadTags ? GTRemoteDownloadTagsAuto
      : GTRemoteDownloadTagsNone
    let pruneOption: GTFetchPruneOption = pruneBranches ? .Yes : .No
    let pruneValue = NSNumber(long: pruneOption.rawValue)
    let tagValue = NSNumber(unsignedInt: tagOption.rawValue)
    let provider = self.credentialProvider(passwordBlock)
    return [
        GTRepositoryRemoteOptionsDownloadTags: tagValue,
        GTRepositoryRemoteOptionsFetchPrune: pruneValue,
        GTRepositoryRemoteOptionsCredentialProvider: provider]
  }
  
  /// Initiates a fetch operation.
  /// - parameter remote: The remote to pull from.
  /// - parameter downloadTags: True to also download tags
  /// - parameter pruneBranches: True to delete obsolete branch refs
  /// - parameter passwordBlock: Callback for getting the user and password
  /// - parameter progressBlock: Return true to stop the operation
  public func fetch(remote remote: XTRemote,
                    downloadTags: Bool,
                    pruneBranches: Bool,
                    passwordBlock: () -> (String, String)?,
                    progressBlock: (git_transfer_progress) -> Bool) throws
  {
    let options = fetchOptions(downloadTags,
                               pruneBranches: pruneBranches,
                               passwordBlock: passwordBlock)
  
    try gtRepo.fetchRemote(remote, withOptions: options) { (progress, stop) in
      stop.memory = ObjCBool(progressBlock(progress.memory))
    }
  }
  
  /// Initiates pulling the given branch.
  /// - parameter branch: Either the local branch or the remote tracking branch.
  /// - parameter remote: The remote to pull from.
  /// - parameter downloadTags: True to also download tags
  /// - parameter pruneBranches: True to delete obsolete branch refs
  /// - parameter passwordBlock: Callback for getting the user and password
  /// - parameter progressBlock: Return true to stop the operation
  public func pull(branch branch: XTBranch,
                   remote: XTRemote,
                   downloadTags: Bool,
                   pruneBranches: Bool,
                   passwordBlock: () -> (String, String)?,
                   progressBlock: (git_transfer_progress) -> Bool) throws
  {
    let options = fetchOptions(downloadTags,
                               pruneBranches: pruneBranches,
                               passwordBlock: passwordBlock)

    try gtRepo.pullBranch(branch.gtBranch,
                          fromRemote: remote,
                          withOptions: options) { (progress, stop) in
      stop.memory = ObjCBool(progressBlock(progress.memory))
    }
  }
  
  /// Initiates pushing the given branch.
  /// - parameter branch: Either the local branch or the remote tracking branch.
  /// - parameter remote: The remote to pull from.
  /// - parameter passwordBlock: Callback for getting the user and password
  /// - parameter progressBlock: Return true to stop the operation
  public func push(branch branch: XTBranch,
                   remote: XTRemote,
                   passwordBlock: () -> (String, String)?,
                   progressBlock: (UInt32, UInt32, size_t) -> Bool) throws
  {
    let provider = self.credentialProvider(passwordBlock)
    let options = [ GTRepositoryRemoteOptionsCredentialProvider: provider ]
    
    try gtRepo.pushBranch(branch.gtBranch,
                          toRemote: remote,
                          withOptions: options) {
      (current, total, bytes, stop) in
      stop.memory = ObjCBool(progressBlock(current, total, bytes))
    }
  }
}

// MARK: Credential helpers

func checkCredentialType(type: GTCredentialType,
                         flag: GTCredentialType) -> Bool
{
  return (type.rawValue & flag.rawValue) != 0
}

func keychainPassword(urlString: String, user: String) -> String?
{
  guard let url = NSURL(string: urlString),
        let server = url.host as NSString?
  else { return nil }
  
  let user = user as NSString
  var passwordLength: UInt32 = 0
  var passwordData: UnsafeMutablePointer<Void> = nil
  
  let err = SecKeychainFindInternetPassword(
      nil,
      UInt32(server.length), server.UTF8String,
      0, nil,
      UInt32(user.length), user.UTF8String,
      0, nil, 0,
      .Any, .Default,
      &passwordLength, &passwordData, nil)
  
  if err != noErr {
    return nil
  }
  return NSString(bytes: passwordData,
                  length: Int(passwordLength),
                  encoding: NSUTF8StringEncoding) as String?
}

func sshCredential(user: String) -> GTCredential?
{
  let publicPath =
      ("~/.ssh/id_rsa.pub" as NSString).stringByExpandingTildeInPath
  let privatePath =
      ("~/.ssh/id_rsa" as NSString).stringByExpandingTildeInPath
  
  return try? GTCredential(
      userName: user,
      publicKeyURL: NSURL(fileURLWithPath: publicPath),
      privateKeyURL: NSURL(fileURLWithPath: privatePath),
      passphrase: "")
}
