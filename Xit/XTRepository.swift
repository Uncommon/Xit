import Foundation


@objc protocol RepositoryType {
  func commit(forSHA sha: String) -> CommitType?
  func commit(forOID oid: GTOID) -> CommitType?
}


/// Stores a repo reference for C callbacks
struct CallbackPayload { let repo: XTRepository }


extension XTRepository: RepositoryType
{
  func commit(forSHA sha: String) -> CommitType?
  {
    return XTCommit(sha: sha, repository: self)
  }
  
  func commit(forOID oid: GTOID) -> CommitType?
  {
    return XTCommit(oid: oid, repository: self)
  }
}


extension XTRepository
{
  enum Error: Swift.Error
  {
    case alreadyWriting
  }
  
  /// Like executeWritingBlock, but using Swift exceptions instead of
  /// returning bool.
  func performWriting(_ block: (() throws -> Void)) throws
  {
    objc_sync_enter(self)
    defer { objc_sync_exit(self) }
    
    if isWriting {
      throw Error.alreadyWriting
    }
    updateIsWriting(true)
    try block()
    updateIsWriting(false)
  }
  
  func rebuildRefsIndex()
  {
    var payload = CallbackPayload(repo: self)
    var callback: git_reference_foreach_cb = { (reference, payload) -> Int32 in
      let repo = payload!.bindMemory(to: XTRepository.self, capacity: 1).pointee
      
      var rawName = git_reference_name(reference)
      guard rawName != nil,
            let name = String(validatingUTF8: rawName!)
      else { return 0 }
      
      var resolved: OpaquePointer? = nil
      guard git_reference_resolve(&resolved, reference) == 0
      else { return 0 }
      defer { git_reference_free(resolved) }
      
      let target = git_reference_target(resolved)
      guard target != nil
      else { return 0}
      let sha = GTOID(gitOid: target!).sha
      var refs = repo.refsIndex[sha] ?? [String]()
      
      refs.append(name)
      repo.refsIndex[sha] = refs
      
      return 0
    }
    
    refsIndex.removeAll()
    git_reference_foreach(gtRepo.git_repository(), callback, &payload)
  }
  
  /// Returns a list of refs that point to the given commit.
  func refs(at sha: String) -> [String]
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
          String(validatingUTF8: UnsafePointer<CChar>(stringArray.strings[i]!))
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
    gtRepo.enumerateStashes { (index, message, oid, stop) in
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
  
  func stagedDiff(file: String) -> XTDiffDelta?
  {
    guard let index = try? gtRepo.index(),
          let indexEntry = index.entry(withPath: file),
          let indexBlob = GTObject(indexEntry: indexEntry, error: nil) as? GTBlob
    else { return nil }
    
    if let headTree = commit(ref: headRef)?.tree,
       let headEntry = try? headTree.entry(withPath: file),
       let headBlob = try? GTObject(treeEntry: headEntry) as? GTBlob {
      return try? XTDiffDelta(from: headBlob, forPath: file,
                              to: indexBlob, forPath: file,
                              options: nil)
    }
    else {
      return try? XTDiffDelta(from: nil, forPath: file,
                              to: indexBlob, forPath: file,
                              options: nil)
    }
  }
  
  func unstagedDiff(file: String) -> XTDiffDelta?
  {
    let url = self.repoURL.appendingPathComponent(file)
    guard let data = try? Data(contentsOf: url)
    else { return nil }
    
    if let index = try? gtRepo.index(),
       let indexEntry = index.entry(withPath: file),
       let indexBlob = GTObject(indexEntry: indexEntry, error: nil) as? GTBlob {
      return try? XTDiffDelta(from: indexBlob, forPath: file,
                              to: data, forPath: file,
                              options: nil)
    }
    else {
      let noBlob: Data? = nil
    
      return try? XTDiffDelta(from: noBlob, forPath: file,
                              to: data, forPath: file,
                              options: nil)
    }
  }
  
  /// Returns the unstaged and staged status of the given file.
  func status(file: String) throws -> (XitChange, XitChange)
  {
    let statusFlags = UnsafeMutablePointer<UInt32>.allocate(capacity: 1)
    let result = git_status_file(statusFlags, gtRepo.git_repository(), file)
    
    if result != 0 {
      throw NSError.git_error(for: result)
    }
    
    let flags = git_status_t(statusFlags.pointee)
    var unstagedChange = XitChange.unmodified
    var stagedChange = XitChange.unmodified
    
    if flags.test(GIT_STATUS_WT_NEW) {
      unstagedChange = .untracked
    }
    else if flags.test(GIT_STATUS_WT_MODIFIED) ||
            flags.test(GIT_STATUS_WT_TYPECHANGE) {
      unstagedChange = .modified
    }
    else if flags.test(GIT_STATUS_WT_DELETED) {
      unstagedChange = .deleted
    }
    else if flags.test(GIT_STATUS_WT_RENAMED) {
      unstagedChange = .renamed
    }
    else if flags.test(GIT_STATUS_IGNORED) {
      unstagedChange = .ignored
    }
    else if flags.test(GIT_STATUS_CONFLICTED) {
      unstagedChange = .conflict
    }
    // ignoring GIT_STATUS_WT_UNREADABLE
    
    if flags.test(GIT_STATUS_INDEX_NEW) {
      stagedChange = .added
    }
    else if flags.test(GIT_STATUS_INDEX_MODIFIED) ||
            flags.test(GIT_STATUS_WT_TYPECHANGE) {
      stagedChange = .modified
    }
    else if flags.test(GIT_STATUS_INDEX_DELETED) {
      stagedChange = .deleted
    }
    else if flags.test(GIT_STATUS_INDEX_RENAMED) {
      stagedChange = .renamed
    }
    
    return (unstagedChange, stagedChange)
  }
  
  /// Reverts the given workspace file to the contents at HEAD.
  @objc(revertFile:error:)
  func revert(file: String) throws
  {
    let options = UnsafeMutablePointer<git_checkout_options>.allocate(
                  capacity: 1)
    var error: NSError? = nil
    
    git_checkout_init_options(options, UInt32(GIT_CHECKOUT_OPTIONS_VERSION))
    withGitStringArray(from: [file]) {
      (stringarray) in
      options.pointee.checkout_strategy = GIT_CHECKOUT_FORCE.rawValue +
                                          GIT_CHECKOUT_RECREATE_MISSING.rawValue
      options.pointee.paths = stringarray
      
      let result = git_checkout_tree(self.gtRepo.git_repository(), nil, options)
      
      if result < 0 {
        error = NSError.git_error(for: result) as NSError?
      }
    }
    
    try error.map { throw $0 }
  }
}

// git_status_t is bridged as a struct instead of a raw UInt32.
extension git_status_t
{
  func test(_ flag: git_status_t) -> Bool
  {
    return (rawValue & flag.rawValue) != 0
  }
}

/// Converts the given array to a `git_strarray` and calls the given block.
/// This is patterned after `withArrayOfCStrings` except that function does not
/// produce the necessary type.
/// - Note: Ideally this would be an extension on Array where `Element == String`
/// but that's not allowed.
/// - parameter array: The array to convert
/// - parameter block: The block called with the resulting `git_strarray`. To
/// use this array outside the block, use `git_strarray_copy()`.
func withGitStringArray(from array: [String],
                        block: @escaping (git_strarray) -> Void)
{
  let lengths = array.map { $0.utf8.count + 1 }
  let offsets = [0] + scan(lengths, 0, +)
  var buffer = [Int8]()
  
  buffer.reserveCapacity(offsets.last!)
  for string in array {
    buffer.append(contentsOf: string.utf8.map({ Int8($0) }))
    buffer.append(0)
  }
  
  buffer.withUnsafeMutableBufferPointer {
    (pointer) in
    let boundPointer = UnsafeMutableRawPointer(pointer.baseAddress!)
                       .bindMemory(to: Int8.self, capacity: buffer.count)
    var cStrings: [UnsafeMutablePointer<Int8>?] =
                  offsets.map { boundPointer + $0 }
    
    cStrings[cStrings.count-1] = nil
    cStrings.withUnsafeMutableBufferPointer({
      (arrayBuffer) in
      let strarray = git_strarray(strings: arrayBuffer.baseAddress,
                                  count: array.count)
      
      block(strarray)
    })
  }
}

// MARK: Push/pull
extension XTRepository
{
  
  func credentialProvider(_ passwordBlock: @escaping () -> (String, String)?)
      -> GTCredentialProvider
  {
    return GTCredentialProvider() {
      (type, url, user) -> GTCredential in
      if checkCredentialType(type, flag: .sshKey) {
        return sshCredential(user) ?? GTCredential()
      }
      
      guard checkCredentialType(type, flag: .userPassPlaintext)
      else { return GTCredential() }
      
      if let password = keychainPassword(urlString: url, user: user) {
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
                           passwordBlock: @escaping () -> (String, String)?)
      -> [String: AnyObject]
  {
    let tagOption = downloadTags ? GTRemoteDownloadTagsAuto
      : GTRemoteDownloadTagsNone
    let pruneOption: GTFetchPruneOption = pruneBranches ? .yes : .no
    let pruneValue = NSNumber(value: pruneOption.rawValue as Int)
    let tagValue = NSNumber(value: tagOption.rawValue as UInt32)
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
  public func fetch(remote: XTRemote,
                    downloadTags: Bool,
                    pruneBranches: Bool,
                    passwordBlock: @escaping () -> (String, String)?,
                    progressBlock: @escaping (git_transfer_progress) -> Bool) throws
  {
    try performWriting() {
      let options = self.fetchOptions(downloadTags: downloadTags,
                                      pruneBranches: pruneBranches,
                                      passwordBlock: passwordBlock)
    
      try self.gtRepo.fetch(remote, withOptions: options) {
        (progress, stop) in
        stop.pointee = ObjCBool(progressBlock(progress.pointee))
      }
    }
  }
  
  /// Initiates pulling the given branch.
  /// - parameter branch: Either the local branch or the remote tracking branch.
  /// - parameter remote: The remote to pull from.
  /// - parameter downloadTags: True to also download tags
  /// - parameter pruneBranches: True to delete obsolete branch refs
  /// - parameter passwordBlock: Callback for getting the user and password
  /// - parameter progressBlock: Return true to stop the operation
  // TODO: Use something other than git_transfer_progress
  public func pull(branch: XTBranch,
                   remote: XTRemote,
                   downloadTags: Bool,
                   pruneBranches: Bool,
                   passwordBlock: @escaping () -> (String, String)?,
                   progressBlock: @escaping (git_transfer_progress) -> Bool) throws
  {
    try performWriting() {
      let options = self.fetchOptions(downloadTags: downloadTags,
                                      pruneBranches: pruneBranches,
                                      passwordBlock: passwordBlock)

      try self.gtRepo.pull(branch.gtBranch,
                                 from: remote,
                                 withOptions: options) {
        (progress, stop) in
        stop.pointee = ObjCBool(progressBlock(progress.pointee))
      }
    }
  }
  
  /// Initiates pushing the given branch.
  /// - parameter branch: Either the local branch or the remote tracking branch.
  /// - parameter remote: The remote to pull from.
  /// - parameter passwordBlock: Callback for getting the user and password
  /// - parameter progressBlock: Return true to stop the operation
  public func push(branch: XTBranch,
                   remote: XTRemote,
                   passwordBlock: @escaping () -> (String, String)?,
                   progressBlock: @escaping (UInt32, UInt32, size_t) -> Bool) throws
  {
    try performWriting() {
      let provider = self.credentialProvider(passwordBlock)
      let options = [ GTRepositoryRemoteOptionsCredentialProvider: provider ]
      
      try self.gtRepo.push(branch.gtBranch,
                                 to: remote,
                                 withOptions: options) {
        (current, total, bytes, stop) in
        stop.pointee = ObjCBool(progressBlock(current, total, bytes))
      }
    }
  }
}

// MARK: Credential helpers

func checkCredentialType(_ type: GTCredentialType,
                         flag: GTCredentialType) -> Bool
{
  return (type.rawValue & flag.rawValue) != 0
}

func keychainPassword(urlString: String, user: String) -> String?
{
  guard let url = URL(string: urlString),
        let server = url.host as NSString?
  else { return nil }
  
  let user = user as NSString
  var passwordLength: UInt32 = 0
  var passwordData: UnsafeMutableRawPointer? = nil
  
  let err = SecKeychainFindInternetPassword(
      nil,
      UInt32(server.length), server.utf8String,
      0, nil,
      UInt32(user.length), user.utf8String,
      0, nil, 0,
      .any, .default,
      &passwordLength, &passwordData, nil)
  
  if err != noErr {
    return nil
  }
  return NSString(bytes: passwordData!,
                  length: Int(passwordLength),
                  encoding: String.Encoding.utf8.rawValue) as String?
}

func sshCredential(_ user: String) -> GTCredential?
{
  let publicPath =
      ("~/.ssh/id_rsa.pub" as NSString).expandingTildeInPath
  let privatePath =
      ("~/.ssh/id_rsa" as NSString).expandingTildeInPath
  
  return try? GTCredential(
      userName: user,
      publicKeyURL: URL(fileURLWithPath: publicPath),
      privateKeyURL: URL(fileURLWithPath: privatePath),
      passphrase: "")
}
