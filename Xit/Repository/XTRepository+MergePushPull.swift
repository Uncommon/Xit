import Foundation

extension XTRepository: RemoteCommunication
{
  public func push(branches: [any LocalBranch],
                   remote: any Remote,
                   callbacks: RemoteCallbacks) throws
  {
    guard let gitRemote = remote as? GitRemote
    else { throw RepoError.unexpected }

    try performWriting {
      var result: Int32
      let names = branches.map { $0.name }

      result = names.withGitStringArray {
        (refspecs) in
        git_remote_callbacks.withCallbacks(callbacks) {
          (gitCallbacks) in
          var mutableArray = refspecs
          var options = git_push_options.defaultOptions()

          options.callbacks = gitCallbacks
          return Signpost.interval(.networkOperation) {
            git_remote_push(gitRemote.remote, &mutableArray, &options)
          }
        }
      }
      try RepoError.throwIfGitError(result)
    }
  }
  
  public func fetch(remote: any Remote, options: FetchOptions) throws
  {
    guard let gitRemote = remote as? GitRemote
    else { throw RepoError.unexpected }

    try performWriting {
      var refspecs = git_strarray.init()
      var result: Int32
      
      result = git_remote_get_fetch_refspecs(&refspecs, gitRemote.remote)
      try RepoError.throwIfGitError(result)
      defer {
        git_strarray_free(&refspecs)
      }
      
      let message = "fetching remote \(remote.name ?? "[unknown]")"
      
      result = git_fetch_options.withOptions(options) {
        withUnsafePointer(to: $0) {
          (options) in
          Signpost.interval(.networkOperation) {
            git_remote_fetch(gitRemote.remote, &refspecs, options, message)
          }
        }
      }
      try RepoError.throwIfGitError(result)
    }
  }
  
  public func pull(branch: any Branch,
                   remote: any Remote,
                   options: FetchOptions) throws
  {
    try fetch(remote: remote, options: options)
    
    var mergeBranch = branch
    
    if let localBranch = branch as? GitLocalBranch,
       let trackingBranch = localBranch.trackingBranch {
      mergeBranch = trackingBranch
    }
    
    try merge(branch: mergeBranch)
  }
}

struct GitTransferProgress: TransferProgress
{
  let gitProgress: git_transfer_progress
  
  var totalObjects: UInt32    { gitProgress.total_objects }
  var indexedObjects: UInt32  { gitProgress.indexed_objects }
  var receivedObjects: UInt32 { gitProgress.received_objects }
  var localObjects: UInt32    { gitProgress.local_objects }
  var totalDeltas: UInt32     { gitProgress.total_deltas }
  var indexedDeltas: UInt32   { gitProgress.indexed_deltas }
  var receivedBytes: Int      { gitProgress.received_bytes }
}

extension XTRepository: Merging
{
  private func fastForwardMerge(branch: GitBranch, remoteBranch: GitBranch) throws
  {
    let branchName: String

    switch remoteBranch {
      case let localBranch as any LocalBranch:
        branchName = localBranch.name
      case let remoteBranch as any RemoteBranch:
        branchName = remoteBranch.shortName
      default:
        assertionFailure("unexpected branch type: \(remoteBranch)")
        throw RepoError.unexpected
    }
    // This actually does write, but the flag is already set
    _ = try executeGit(args: ["merge", "--ff-only", branchName], writes: false)

    // In some cases, fast-forward merging with libgit2 can clobber unrelated
    // workspace changes, so CLI is used instead for now.
    #if false
    guard let remoteCommit = remoteBranch.targetCommit as? GitCommit
    else { throw RepoError.unexpected }
    
    do {
      // move the branch ref
      guard let branchRef = GitReference(name: branch.name, repository: gitRepo)
      else { throw RepoError.notFound }
      
      branchRef.setTarget(remoteCommit.oid,
                          logMessage: "merge \(remoteBranch.name): Fast-forward")
      
      // check out target
      var result: Int32
      var checkoutOptions = git_checkout_options.defaultOptions()
      let notifyCallback: git_checkout_notify_cb = {
        (_, _, _, _, _, _) -> Int32 in
        GIT_EMERGECONFLICT.rawValue
      }

      checkoutOptions.checkout_strategy = [GIT_CHECKOUT_FORCE,
                                           GIT_CHECKOUT_ALLOW_CONFLICTS]
      checkoutOptions.notify_flags = GIT_CHECKOUT_NOTIFY_CONFLICT.rawValue
      checkoutOptions.notify_cb = notifyCallback
      
      result = git_checkout_tree(gitRepo, remoteCommit.commit, &checkoutOptions)
      try RepoError.throwIfGitError(result)
      
      // move HEAD
      result = git_repository_set_head(gitRepo, branch.name)
      try RepoError.throwIfGitError(result)
    }
    #endif
  }
  
  private func normalMerge(fromBranch: GitBranch, fromCommit: GitCommit,
                           targetBranch: GitBranch, targetCommit: GitCommit) throws
  {
    do {
      var annotated: OpaquePointer? = try annotatedCommit(branch: fromBranch)
      
      defer {
        git_annotated_commit_free(annotated)
      }
      
      var mergeOptions = git_merge_options.defaultOptions()
      var checkoutOptions = git_checkout_options.defaultOptions()
      guard let index = self.index
      else {
        throw RepoError.unexpected
      }

      checkoutOptions.checkout_strategy = GIT_CHECKOUT_SAFE.rawValue |
                                          GIT_CHECKOUT_ALLOW_CONFLICTS.rawValue
      try index.refresh()
      
      let result = git_merge(gitRepo, &annotated, 1,
                             &mergeOptions, &checkoutOptions)

      switch git_error_code(rawValue: result) {
        case GIT_OK:
          break
        case GIT_ECONFLICT:
          throw RepoError.localConflict
        default:
          throw RepoError.gitError(result)
      }

      if index.hasConflicts {
        throw RepoError.conflict
      }
      else {
        let tree = try index.writeTree() as! GitTree
        
        _ = try createCommit(with: tree,
                             message: "Merge branch \(fromBranch.name)",
                             parents: [targetCommit, fromCommit],
                             updatingReference: targetBranch.name)
      }
    }
  }
  
  /// The full path to the MERGE_HEAD file
  var mergeHeadPath: String
  { self.gitDirectoryPath +/ "MERGE_HEAD" }
  
  /// The full path to the CHERRY_PICK_HEAD file
  var cherryPickHeadPath: String
  { self.gitDirectoryPath +/ "CHERRY_PICK_HEAD" }
  
  private func mergePreCheck() throws
  {
    if index?.hasConflicts ?? false {
      throw RepoError.localConflict
    }
    
    if FileManager.default.fileExists(atPath: mergeHeadPath) {
      throw RepoError.mergeInProgress
    }
    if FileManager.default.fileExists(atPath: cherryPickHeadPath) {
      throw RepoError.cherryPickInProgress
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
  public func merge(branch: any Branch) throws
  {
    try performWriting {
      try writingMerge(branch: branch)
    }
  }
  
  fileprivate func writingMerge(branch: any Branch) throws
  {
    guard let gitBranch = branch as? GitBranch
    else { return }
    
    do {
      try mergePreCheck()
      
      guard let currentBranchName = currentBranch,
            let targetBranch = GitLocalBranch(repository: gitRepo,
                                              name: currentBranchName,
                                              config: config)
      else { throw RepoError.detachedHead }
      guard let targetCommit = targetBranch.targetCommit as? GitCommit,
            let remoteCommit = branch.targetCommit as? GitCommit
      else { throw RepoError.unexpected }
      
      if targetCommit.id == remoteCommit.id {
        return
      }
      
      let analysis = try analyzeMerge(from: branch)
      
      if analysis.contains(.upToDate) {
        return
      }
      if analysis.contains(.unborn) {
        throw RepoError.unexpected
      }
      if analysis.contains(.fastForward) {
        try fastForwardMerge(branch: targetBranch, remoteBranch: gitBranch)
        return
      }
      if analysis.contains(.normal) {
        try normalMerge(fromBranch: gitBranch, fromCommit: remoteCommit,
                        targetBranch: targetBranch, targetCommit: targetCommit)
        return
      }
      throw RepoError.unexpected
    }
  }
  
  struct MergeAnalysis: OptionSet, Sendable
  {
    let rawValue: UInt32
    
    /// No merge possible
    static let none: MergeAnalysis = []
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
  func annotatedCommit(_ commit: GitCommit) throws -> OpaquePointer
  {
    return try OpaquePointer.from {
      (annotated) in
      commit.id.withUnsafeOID {
        git_annotated_commit_lookup(&annotated, gitRepo, $0)
      }
    }
  }
  
  /// Wraps `git_annotated_commit_from_ref`
  /// - parameter branch: Branch to look up the tip commit
  /// - returns: An `OpaquePointer` wrapping a `git_annotated_commit`
  func annotatedCommit(branch: GitBranch) throws -> OpaquePointer
  {
    return try OpaquePointer.from {
      git_annotated_commit_from_ref(&$0, gitRepo, branch.branchRef)
    }
  }

  /// Determines what sort of merge can be done from the given branch.
  /// - parameter branch: Branch to merge into the current branch.
  /// - parameter fastForward: True for fast-forward only, false for
  /// fast-forward not allowed, or nil for no preference.
  func analyzeMerge(from branch: any Branch,
                    fastForward: Bool? = nil) throws -> MergeAnalysis
  {
    guard let branch = branch as? GitBranch,
          branch.targetCommit != nil
    else { throw RepoError.unexpected }
    
    let preference =
          UnsafeMutablePointer<git_merge_preference_t>.allocate(capacity: 1)
    defer {
      preference.deallocate()
    }
    
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
      analysis.deallocate()
    }
    
    let result = withUnsafeMutablePointer(to: &annotated) {
      git_merge_analysis(analysis, preference, gitRepo, $0, 1)
    }

    try RepoError.throwIfGitError(result)
    return MergeAnalysis(rawValue: analysis.pointee.rawValue)
  }
}
