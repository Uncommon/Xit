import Foundation

extension XTRepository
{
  
  func credentialProvider(_ passwordBlock: @escaping () -> (String, String)?)
      -> GTCredentialProvider
  {
    return GTCredentialProvider {
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
                    progressBlock: @escaping (git_transfer_progress) -> Bool)
                    throws
  {
    try performWriting {
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
    try performWriting {
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
  
  func pull2(branch: XTBranch,
             remote: XTRemote,
             downloadTags: Bool,
             pruneBranches: Bool,
             passwordBlock: @escaping () -> (String, String)?,
             progressBlock: @escaping (git_transfer_progress) -> Bool) throws
  {
    try fetch(remote: remote, downloadTags: downloadTags,
              pruneBranches: pruneBranches, passwordBlock: passwordBlock,
              progressBlock: progressBlock)
    
    var mergeBranch = branch
    
    if let localBranch = branch as? XTLocalBranch,
       let trackingBranch = localBranch.trackingBranch {
      mergeBranch = trackingBranch
    }
    
    try merge(branch: mergeBranch)
  }
  
  private func fastForwardMerge(branch: XTBranch, remoteBranch: XTBranch) throws
  {
    guard let remoteName = remoteBranch.name,
          let remoteCommit = remoteBranch.targetCommit,
          let remoteSHA = remoteCommit.sha
    else { throw Error.unexpected }
    
    do {
      let targetReference = branch.gtBranch.reference
      let updated = try targetReference.updatingTarget(
            remoteSHA,
            message: "merge \(remoteName): Fast-forward")
      let options = GTCheckoutOptions(strategy: [.force, .allowConflicts],
                                      notifyFlags: [.conflict]) {
        (_, _, _, _, _) -> Int32 in
        return GIT_EMERGECONFLICT.rawValue
      }
      
      try gtRepo.checkoutReference(updated, options: options)
    }
    catch let error as NSError where error.domain == GTGitErrorDomain {
      throw Error(gitNSError: error)
    }
  }
  
  private func normalMerge(fromBranch: XTBranch, fromCommit: XTCommit,
                           targetName: String, targetCommit: XTCommit) throws
  {
    guard let fromName = fromBranch.name
    else { throw Error.unexpected }
    
    do {
      var annotated: OpaquePointer? = try annotatedCommit(fromCommit)
      var mergeOptions = git_merge_options.defaultOptions()
      var checkoutOptions = git_checkout_options.defaultOptions()
      var result: Int32 = 0
      
      checkoutOptions.checkout_strategy = GIT_CHECKOUT_SAFE.rawValue |
                                          GIT_CHECKOUT_ALLOW_CONFLICTS.rawValue

      withUnsafeMutablePointer(to: &annotated) {
        (annotated) in
        withUnsafePointer(to: &mergeOptions) {
          (mergeOptions) in
          withUnsafePointer(to: &checkoutOptions) {
            (checkoutOptions) in
            result = git_merge(gtRepo.git_repository(), annotated, 1,
                               mergeOptions, checkoutOptions)
          }
        }
      }
      switch git_error_code(rawValue: result) {
        case GIT_OK:
          break
        case GIT_ECONFLICT:
          throw Error.conflict
        default:
          throw Error.gitError(result)
      }
      
      let index = try gtRepo.index()
      
      if index.hasConflicts {
        throw Error.conflict
      }
      else {
        let parents = [targetCommit, fromCommit].map { $0.gtCommit }
        let tree = try index.writeTree()
        
        _ = try gtRepo.createCommit(with: tree,
                                    message: "Merge branch \(fromName)",
                                    parents: parents,
                                    updatingReferenceNamed: targetName)
      }
    }
    catch let error as NSError where error.domain == GTGitErrorDomain {
      throw Error(gitNSError: error)
    }
  }
  
  /// The full path to the MERGE_HEAD file
  var mergeHeadPath: String
  {
    return self.gitDirectoryURL.appendingPathComponent("MERGE_HEAD").path
  }
  
  /// The full path to the CHERRY_PICK_HEAD file
  var cherryPickHeadPath: String
  {
    return self.gitDirectoryURL.appendingPathComponent("CHERRY_PICK_HEAD").path
  }
  
  private func mergePreCheck() throws
  {
    let index = try gtRepo.index()
    
    if index.hasConflicts {
      throw Error.indexConflict
    }
    
    if FileManager.default.fileExists(atPath: mergeHeadPath) {
      throw Error.mergeInProgress
    }
    if FileManager.default.fileExists(atPath: cherryPickHeadPath) {
      throw Error.cherryPickInProgress
    }
  }
  
  // What git does: (merge.c:cmd_merge)
  // - Check for detached HEAD
  // - Look up merge config values, counting options for the target branch
  //   (merge.c:git_merge_config)
  // - Parse the specified options
  // * Action: abort
  // * Action: continue
  // - Abort if there are unmerged files in the index
  // - Abort if MERGE_HEAD already exists
  // - Abort if CHERRY_PICK_HEAD already exists
  // - resolve_undo_clear: clear out old morge resolve stuff?
  // * Handle merge onto unborn branch
  // - If required, verify signatures on merge heads
  // - Set GIT_REFLOG_ACTION env
  // - Set env GITHEAD_[sha]
  // - Decide strategies, default recursive or octopus
  // - Find merge base(s)
  // - Put ORIG_HEAD ref on head commit
  // - Die if no bases found, unless --allow-unrelated-histories
  // - If the merge head *is* the base, already up-to-date
  // * Fast-forward
  // * Try trivial merge (if not ff-only) - read_tree_trivial, merge_trivial
  // * Octopus: check if up to date
  // - ff-only fails here
  // - Stash local changes if multiple strategies will be tried
  // - For each strategy:
  //   - start clean if not first iteration
  //   - try the strategy
  //   - evaluate results; stop if there was no conflict
  // * If the last strategy had no conflicts, finalize it
  // - All strategies failed?
  // - Redo the best strategy if it wasn't the last one tried
  // - Finalize with conflicts - write MERGE_HEAD, etc
  
  func merge(branch: XTBranch) throws
  {
    do {
      try mergePreCheck()
      
      guard let currentBranchName = currentBranch,
            let targetBranch = XTLocalBranch(name: currentBranchName,
                                             repository: self)
      else { throw Error.detachedHead }
      guard let targetCommit = targetBranch.targetCommit,
            let remoteCommit = branch.targetCommit
      else { throw Error.unexpected }
      
      if targetCommit.oid == remoteCommit.oid {
        return
      }
      
      let analysis = try analyzeMerge(from: branch)
      
      if analysis.contains(.upToDate) {
        return
      }
      if analysis.contains(.unborn) {
        throw Error.unexpected
      }
      if analysis.contains(.fastForward) {
        try fastForwardMerge(branch: targetBranch, remoteBranch: branch)
        return
      }
      if analysis.contains(.normal) {
        try normalMerge(fromBranch: branch, fromCommit: remoteCommit,
                        targetName: targetBranch.name ??
                                    "refs/heads/\(currentBranchName)",
                        targetCommit: targetCommit)
        return
      }
      throw Error.unexpected
    }
    catch let error as NSError where error.domain == GTGitErrorDomain {
      throw Error(gitNSError: error)
    }
  }
  
  struct MergeAnalysis: OptionSet
  {
    let rawValue: UInt32
    
    /// No merge possible
    static let none = MergeAnalysis(rawValue: 0)
    /// Normal merge
    static let normal = MergeAnalysis(rawValue: 0b0001)
    /// Already up to date, nothing to do
    static let upToDate = MergeAnalysis(rawValue: 0b0010)
    /// Fast-forward morge: just advance the branch ref
    static let fastForward = MergeAnalysis(rawValue: 0b0100)
    /// Merge target is an unborn branch
    static let unborn = MergeAnalysis(rawValue: 0b1000)
  }
  
  /// Wraps `git_annotated_commit_lookup`
  /// - parameter commit: The commit to look up.
  /// - returns: An `OpaquePointer` wrapping a `git_annotated_commit`
  func annotatedCommit(_ commit: XTCommit) throws -> OpaquePointer
  {
    let annotated = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
    let result = git_annotated_commit_lookup(annotated, gtRepo.git_repository(),
                                             commit.oid.unsafeOID())
    
    if result != GIT_OK.rawValue {
      throw Error.gitError(result)
    }
    if let annotatedCommit = annotated.pointee {
      return annotatedCommit
    }
    else {
      throw Error.unexpected
    }
  }

  /// Determines what sort of merge can be done from the given branch.
  /// - parameter branch: Branch to merge into the current branch.
  /// - parameter fastForward: True for fast-forward only, false for
  /// fast-forward not allowed, or nil for no preference.
  func analyzeMerge(from branch: XTBranch,
                    fastForward: Bool? = nil) throws -> MergeAnalysis
  {
    guard let commit = branch.targetCommit
    else { throw Error.unexpected }
    
    let preference =
          UnsafeMutablePointer<git_merge_preference_t>.allocate(capacity: 1)
    
    if let fastForward = fastForward {
      preference.pointee = fastForward ? GIT_MERGE_PREFERENCE_FASTFORWARD_ONLY
                                       : GIT_MERGE_PREFERENCE_NO_FASTFORWARD
    }
    else {
      preference.pointee = GIT_MERGE_PREFERENCE_NONE
    }
    
    let analysis =
          UnsafeMutablePointer<git_merge_analysis_t>.allocate(capacity: 1)
    var annotated: OpaquePointer? = try annotatedCommit(commit)
    let result = withUnsafeMutablePointer(to: &annotated) {
      git_merge_analysis(analysis, preference, gtRepo.git_repository(), $0, 1)
    }
    
    guard result == GIT_OK.rawValue
    else { throw Error.gitError(result) }
    
    return MergeAnalysis(rawValue: analysis.pointee.rawValue)
  }
  
  /// Initiates pushing the given branch.
  /// - parameter branch: Either the local branch or the remote tracking branch.
  /// - parameter remote: The remote to pull from.
  /// - parameter passwordBlock: Callback for getting the user and password
  /// - parameter progressBlock: Return true to stop the operation
  public func push(branch: XTBranch,
                   remote: XTRemote,
                   passwordBlock: @escaping () -> (String, String)?,
                   progressBlock: @escaping (UInt32, UInt32, size_t) -> Bool)
                   throws
  {
    try performWriting {
      let provider = self.credentialProvider(passwordBlock)
      let options = [ GTRepositoryRemoteOptionsCredentialProvider: provider ]
      
      try self.gtRepo.push(branch.gtBranch, to: remote, withOptions: options) {
        (current, total, bytes, stop) in
        stop.pointee = ObjCBool(progressBlock(current, total, bytes))
      }
    }
  }
}

// MARK: Credential helpers

fileprivate func checkCredentialType(_ type: GTCredentialType,
                                     flag: GTCredentialType) -> Bool
{
  return (type.rawValue & flag.rawValue) != 0
}

fileprivate func keychainPassword(urlString: String, user: String) -> String?
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

fileprivate func sshCredential(_ user: String) -> GTCredential?
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
