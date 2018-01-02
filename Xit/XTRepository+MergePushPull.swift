import Foundation

public protocol TransferProgress
{
  var totalObjects: UInt32 { get }
  var indexedObjects: UInt32 { get }
  var receivedObjects: UInt32 { get }
  var localObjects: UInt32 { get }
  var totalDeltas: UInt32 { get }
  var indexedDeltas: UInt32 { get }
  var receivedBytes: Int { get }
}

extension TransferProgress
{
  var progress: Float
  {
    return Float(receivedObjects) / Float(totalObjects)
  }
}

extension XTRepository
{
  struct GitTransferProgress: TransferProgress
  {
    let gitProgress: git_transfer_progress
    
    var totalObjects: UInt32    { return gitProgress.total_objects }
    var indexedObjects: UInt32  { return gitProgress.indexed_objects }
    var receivedObjects: UInt32 { return gitProgress.received_objects }
    var localObjects: UInt32    { return gitProgress.local_objects }
    var totalDeltas: UInt32     { return gitProgress.total_deltas }
    var indexedDeltas: UInt32   { return gitProgress.indexed_deltas }
    var receivedBytes: Int      { return gitProgress.received_bytes }
  }
  
  public struct FetchOptions
  {
    let downloadTags, pruneBranches: Bool
    let passwordBlock: () -> (String, String)?
    let progressBlock: (TransferProgress) -> Bool
  }
  
  func credentialProvider(_ passwordBlock: @escaping () -> (String, String)?)
      -> GTCredentialProvider
  {
    return GTCredentialProvider {
      (type, urlString, user) -> GTCredential in
      if checkCredentialType(type, flag: .sshKey) {
        return sshCredential(user) ?? GTCredential()
      }
      
      guard checkCredentialType(type, flag: .userPassPlaintext)
      else { return GTCredential() }
      
      if let url = URL(string: urlString),
         let password = XTKeychain.findItem(url: url, user: user).0 {
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
    let provider = credentialProvider(passwordBlock)
    
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
  public func fetch(remote: Remote,
                    options: FetchOptions) throws
  {
    try performWriting {
      let gtOptions = self.fetchOptions(downloadTags: options.downloadTags,
                                        pruneBranches: options.pruneBranches,
                                        passwordBlock: options.passwordBlock)
      guard let gtRemote = GTRemote(gitRemote: (remote as! GitRemote).remote,
                                    in: gtRepo)
      else { throw Error.unexpected }
      
      try self.gtRepo.fetch(gtRemote, withOptions: gtOptions) {
        (progress, stop) in
        let transferProgress = GitTransferProgress(gitProgress: progress.pointee)
        
        stop.pointee = ObjCBool(options.progressBlock(transferProgress))
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
  func pull(branch: Branch,
            remote: Remote,
            options: FetchOptions) throws
  {
    try fetch(remote: remote, options: options)
    
    var mergeBranch = branch
    
    if let localBranch = branch as? GitLocalBranch,
       let trackingBranch = localBranch.trackingBranch as? GitRemoteBranch {
      mergeBranch = trackingBranch
    }
    
    try merge(branch: mergeBranch)
  }
  
  private func fastForwardMerge(branch: GitBranch, remoteBranch: GitBranch) throws
  {
    guard let remoteCommit = remoteBranch.targetCommit
    else { throw Error.unexpected }
    
    do {
      guard let targetReference = GTReference(gitReference: branch.branchRef,
                                              repository: gtRepo)
      else { throw Error.unexpected }
      let updated = try targetReference.updatingTarget(
            remoteCommit.sha,
            message: "merge \(remoteBranch.name): Fast-forward")
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
  
  private func normalMerge(fromBranch: GitBranch, fromCommit: XTCommit,
                           targetBranch: GitBranch, targetCommit: XTCommit) throws
  {
    do {
      var annotated: OpaquePointer? = try annotatedCommit(branch: fromBranch)
      
      defer {
        git_annotated_commit_free(annotated)
      }
      
      var mergeOptions = git_merge_options.defaultOptions()
      var checkoutOptions = git_checkout_options.defaultOptions()
      var result: Int32 = 0
      
      checkoutOptions.checkout_strategy = GIT_CHECKOUT_SAFE.rawValue |
                                          GIT_CHECKOUT_ALLOW_CONFLICTS.rawValue

      try withUnsafeMutablePointer(to: &annotated) {
        (annotated) in
        try withUnsafePointer(to: &mergeOptions) {
          (mergeOptions) in
          try withUnsafePointer(to: &checkoutOptions) {
            (checkoutOptions) in
            try gtRepo.index().refresh()
            result = git_merge(gitRepo, annotated, 1,
                               mergeOptions, checkoutOptions)
          }
        }
      }
      switch git_error_code(rawValue: result) {
        case GIT_OK:
          break
        case GIT_ECONFLICT:
          throw Error.localConflict
        default:
          throw Error.gitError(result)
      }
      
      let index = try gtRepo.index()
      
      if index.hasConflicts {
        throw Error.conflict
      }
      else {
        let parents = [targetCommit, fromCommit].flatMap
          { GTCommit(obj: $0.commit, in: gtRepo) }
        let tree = try index.writeTree()
        
        _ = try gtRepo.createCommit(with: tree,
                                    message: "Merge branch \(fromBranch.name)",
                                    parents: parents,
                                    updatingReferenceNamed: targetBranch.name)
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
      throw Error.localConflict
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
  
  /// Merges the given branch into the current branch.
  func merge(branch: Branch) throws
  {
    try performWriting {
      try self.writingMerge(branch: branch)
    }
  }
  
  fileprivate func writingMerge(branch: Branch) throws
  {
    guard let branch = branch as? GitBranch
    else { return }
    
    do {
      try mergePreCheck()
      
      guard let currentBranchName = currentBranch,
            let targetBranch = GitLocalBranch(repository: self,
                                              name: currentBranchName)
      else { throw Error.detachedHead }
      guard let targetCommit = targetBranch.targetCommit,
            let remoteCommit = branch.targetCommit
      else { throw Error.unexpected }
      
      if targetCommit.oid.equals(remoteCommit.oid) {
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
                        targetBranch: targetBranch, targetCommit: targetCommit)
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
    guard let oid = commit.oid as? GitOID
    else { throw Error.unexpected }
    let annotated = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
    let result = git_annotated_commit_lookup(annotated, gitRepo, oid.unsafeOID())
    
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
  
  /// Wraps `git_annotated_commit_from_ref`
  /// - parameter branch: Branch to look up the tip commit
  /// - returns: An `OpaquePointer` wrapping a `git_annotated_commit`
  func annotatedCommit(branch: GitBranch) throws -> OpaquePointer
  {
    let annotated = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
    let result = git_annotated_commit_from_ref(
          annotated, gitRepo, branch.branchRef)
    
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
  func analyzeMerge(from branch: Branch,
                    fastForward: Bool? = nil) throws -> MergeAnalysis
  {
    guard let branch = branch as? GitBranch,
          let commit = branch.targetCommit
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
    var annotated: OpaquePointer? = try annotatedCommit(branch: branch)
    
    defer {
      git_annotated_commit_free(annotated)
    }
    
    let result = withUnsafeMutablePointer(to: &annotated) {
      git_merge_analysis(analysis, preference, gitRepo, $0, 1)
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
  public func push(branch: Branch,
                   remote: Remote,
                   passwordBlock: @escaping () -> (String, String)?,
                   progressBlock: @escaping (UInt32, UInt32, size_t) -> Bool)
                   throws
  {
    try performWriting {
      let provider = self.credentialProvider(passwordBlock)
      let options = [ GTRepositoryRemoteOptionsCredentialProvider: provider ]
      guard let localBranch = branch as? GitLocalBranch,
            let localGTRef = GTReference(gitReference: localBranch.branchRef,
                                         repository: gtRepo),
            let localGTBranch = GTBranch(reference: localGTRef),
            let gtRemote = GTRemote(gitRemote: (remote as! GitRemote).remote,
                                    in: gtRepo)
      else { throw Error.unexpected }
      
      try self.gtRepo.push(localGTBranch, to: gtRemote, withOptions: options) {
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
