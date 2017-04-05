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
      let options = GTCheckoutOptions(strategy: .allowConflicts,
                                      notifyFlags: [.conflict]) {
        (why, path, baseline, target, workdir) -> Int32 in
        return GIT_EMERGECONFLICT.rawValue
      }
      
      try gtRepo.checkoutReference(updated, options: options)
    }
    catch let error as NSError where error.domain == GTGitErrorDomain {
      throw Error(gitCode: git_error_code(rawValue: Int32(error.code)))
    }
  }
  
  private func normalMerge(fromBranch: XTBranch, fromCommit: XTCommit,
                           targetName: String, targetCommit: XTCommit) throws
  {
    guard let targetTree = targetCommit.tree,
          let fromTree = fromCommit.tree,
          let fromName = fromBranch.name
    else { throw Error.unexpected }
    
    do {
      // Does it help to find the ancestor?
      let index = try targetTree.merge(fromTree, ancestor: nil)
      
      if index.hasConflicts {
        var conflicts = [String]()
        
        try index.enumerateConflictedFiles {
          (ancestor, ours, theirs, stop) in
          conflicts.append(ours.path)
        }
        
        let annotated = try annotatedCommit(fromCommit)
        let unsafeAnnotated = UnsafeMutablePointer<OpaquePointer?>(annotated)
        var mergeOptions = git_merge_options()
        var checkoutOptions = git_checkout_options()
        
        mergeOptions.version = UInt32(GIT_MERGE_OPTIONS_VERSION)
        checkoutOptions.version = UInt32(GIT_CHECKOUT_OPTIONS_VERSION)
        checkoutOptions.checkout_strategy = GIT_CHECKOUT_SAFE.rawValue |
                                            GIT_CHECKOUT_ALLOW_CONFLICTS.rawValue

        withUnsafePointer(to: &mergeOptions) {
          (mergeOptions) in
          withUnsafePointer(to: &checkoutOptions) {
            (checkoutOptions) in
            _ = git_merge(gtRepo.git_repository(), unsafeAnnotated, 1,
                          mergeOptions, checkoutOptions)
          }
        }
        throw Error.conflict(conflicts)
      }
      
      let newTree = try index.writeTree(to: gtRepo)
      let message = "Merge branch '\(fromName)'"
      let parents = [targetCommit, fromCommit].map { $0.gtCommit }
      
      _ = try gtRepo.createCommit(with: newTree, message: message,
                                  parents: parents,
                                  updatingReferenceNamed: targetName)
      
      try gtRepo.checkoutReference(
            fromBranch.reference,
            options: GTCheckoutOptions(strategy: .conflictStyleMerge))
    }
    catch let error as NSError where error.domain == GTGitErrorDomain {
      throw Error(gitCode: git_error_code(rawValue: Int32(error.code)))
    }
  }
  
  func merge(branch: XTBranch) throws
  {
    guard let currentBranchName = currentBranch,
          let targetBranch = XTBranch(name: currentBranchName, repository: self)
    else { throw Error.detachedHead }
    guard let targetCommit = targetBranch.targetCommit,
          let remoteCommit = branch.targetCommit
    else { throw Error.unexpected }
    
    if targetCommit.oid == remoteCommit.oid {
      return
    }
    
    let analysis = try analyzeMerge(from: branch)
    
    switch analysis {
      case .none, .upToDate:
        return
      case .fastForward:
        try fastForwardMerge(branch: targetBranch, remoteBranch: branch)
      case .normal:
        break
      case .unborn:
        throw Error.unexpected
    }
  }
  
  // C enum values come in as struct instances, and only literals can be used
  // as Swift enum values.
  enum MergeAnalysis: UInt32
  {
    case none = 0             // GIT_MERGE_ANALYSIS_NONE
    case normal = 0b0001      // GIT_MERGE_ANALYSIS_NORMAL
    case upToDate = 0b0010    // GIT_MERGE_ANALYSIS_UP_TO_DATE
    case fastForward = 0b0100 // GIT_MERGE_ANALYSIS_FASTFORWARD
    case unborn = 0b1000      // GIT_MERGE_ANALYSIS_UNBORN
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
    
    let analysis =
          UnsafeMutablePointer<git_merge_analysis_t>.allocate(capacity: 1)
    let preference =
          UnsafeMutablePointer<git_merge_preference_t>.allocate(capacity: 1)
    
    if let fastForward = fastForward {
      preference.pointee = fastForward ? GIT_MERGE_PREFERENCE_FASTFORWARD_ONLY
                                       : GIT_MERGE_PREFERENCE_NO_FASTFORWARD
    }
    else {
      preference.pointee = GIT_MERGE_PREFERENCE_NONE
    }
    
    let annotated = try annotatedCommit(commit)
    let unsafeAnnotated = UnsafeMutablePointer<OpaquePointer?>(annotated)
    let result = git_merge_analysis(analysis, preference, gtRepo.git_repository(),
                                    unsafeAnnotated, 1)
    
    guard result == GIT_OK.rawValue
    else { throw Error.gitError(result) }
    guard let returnValue = MergeAnalysis(rawValue: analysis.pointee.rawValue)
    else { throw Error.unexpected }
    
    return returnValue
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
