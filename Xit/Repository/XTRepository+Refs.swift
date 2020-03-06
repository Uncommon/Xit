import Foundation

extension ResetMode
{
  var gitReset: git_reset_t
  {
    switch self {
      case .soft:  return GIT_RESET_SOFT
      case .mixed: return GIT_RESET_MIXED
      case .hard:  return GIT_RESET_HARD
    }
  }
}

extension XTRepository: Branching
{
  @objc public var currentBranch: String?
  {
    mutex.lock()
    defer { mutex.unlock() }
    if cachedBranch == nil {
      refsChanged()
    }
    return cachedBranch
  }
  
  public var localBranches: AnySequence<LocalBranch>
  {
    return AnySequence { LocalBranchIterator(repo: self) }
  }
  
  public var remoteBranches: AnySequence<RemoteBranch>
  {
    return AnySequence { RemoteBranchIterator(repo: self) }
  }

  public func createBranch(named name: String,
                           target: String) throws -> LocalBranch?
  {
    guard let targetRef = GitReference(name: target,
                                       repository: gitRepo),
          let targetOID = targetRef.targetOID,
          let targetCommit = GitCommit(oid: targetOID, repository: gitRepo)
    else { return nil }
    
    var branchRef: OpaquePointer?
    let result = git_branch_create(&branchRef, gitRepo, name,
                                   targetCommit.commit, 0)
    
    try RepoError.throwIfGitError(result)
    return branchRef.map { GitLocalBranch(branch: $0, config: config) }
  }
  
  /// Renames the given local branch.
  public func rename(branch: String, to newName: String) throws
  {
    if isWriting {
      throw RepoError.alreadyWriting
    }
    
    var branchRef: OpaquePointer? = nil
    var result = git_branch_lookup(&branchRef, gitRepo, branch, GIT_BRANCH_LOCAL)
    
    try RepoError.throwIfGitError(result)
    
    var newRef: OpaquePointer? = nil
    
    result = git_branch_move(&newRef, branchRef, newName, 0)
    try RepoError.throwIfGitError(result)
  }

  public func localBranch(named name: String) -> LocalBranch?
  {
    let fullName = RefPrefixes.heads +/ name
    
    if let branch = cachedBranches[fullName] as? GitLocalBranch {
      return branch
    }
    else {
      guard let branch = GitLocalBranch(repository: gitRepo, name: name,
                                        config: config)
      else { return nil }
      
      addCachedBranch(branch)
      return branch
    }
  }
  
  public func remoteBranch(named name: String, remote: String) -> RemoteBranch?
  {
    return remoteBranch(named: remote +/ name)
  }
  
  public func remoteBranch(named name: String) -> RemoteBranch?
  {
    let fullName = RefPrefixes.remotes +/ name
    
    if let branch = cachedBranches[fullName] as? GitRemoteBranch {
      return branch
    }
    else {
      guard let branch = GitRemoteBranch(repository: gitRepo,
                                         name: name, config: config)
      else { return nil }
      
      addCachedBranch(branch)
      return branch
    }
  }
  
  public func localBranch(tracking remoteBranch: RemoteBranch) -> LocalBranch?
  {
    return localTrackingBranch(forBranchRef: remoteBranch.name)
  }
  
  // swiftlint:disable:next force_try
  static let remoteRegex = try!
      NSRegularExpression(pattern: "\\Abranch\\.(.*)\\.remote",
                          options: [])

  public func localTrackingBranch(forBranchRef branch: String) -> LocalBranch?
  {
    guard let ref = RefName(rawValue: branch),
          case let .remoteBranch(remote, branch) = ref
    else { return nil }
    
    // Looping through all the branches can be expensive
    for entry in config.entries {
      let name = entry.name
      guard let match = XTRepository.remoteRegex
                                    .firstMatch(in: name, options: [],
                                                range: name.fullNSRange),
            match.numberOfRanges == 2,
            let branchRange = Range(match.range(at: 1), in: name),
            entry.stringValue == remote
      else { continue }
      let entryBranch = String(name[branchRange])
      guard let mergeName = config.branchMerge(entryBranch)
      else { continue }

      let stripped = branch.droppingPrefix(RefPrefixes.remotes +/ remote)
      let expectedMergeName = RefPrefixes.heads +/ stripped
      
      if mergeName == expectedMergeName {
        return localBranch(named: entryBranch)
      }
    }
    return nil
  }
  
  public func reset(toCommit target: Commit, mode: ResetMode) throws
  {
    guard let commit = target as? GitCommit
    else { throw RepoError.unexpected }
    
    let gitReset = mode.gitReset
    let result = git_reset(gitRepo, commit.commit, gitReset, nil)
    
    try RepoError.throwIfGitError(result)
  }
}

extension XTRepository: Tagging
{
  public func createTag(name: String, targetOID: OID, message: String?) throws
  {
    try performWriting {
      guard let commit = GitCommit(oid: targetOID,
                                   repository: gitRepo)
        else { throw RepoError.notFound }
      
      var oid = git_oid()
      let signature = UnsafeMutablePointer<UnsafeMutablePointer<git_signature>?>
        .allocate(capacity: 1)
      let sigResult = git_signature_default(signature, gitRepo)
      
      try RepoError.throwIfGitError(sigResult)
      guard let finalSig = signature.pointee
        else { throw RepoError.unexpected }
      
      let result = git_tag_create(&oid, gitRepo, name,
                                  commit.commit, finalSig, message, 0)
      
      try RepoError.throwIfGitError(result)
    }
  }
  
  public func createLightweightTag(name: String, targetOID: OID) throws
  {
    try performWriting {
      guard let commit = GitCommit(oid: targetOID,
                                   repository: gitRepo)
        else { throw RepoError.notFound }
      
      var oid = git_oid()
      let result = git_tag_create_lightweight(&oid, gitRepo, name,
                                              commit.commit, 0)
      
      try RepoError.throwIfGitError(result)
    }
  }
  
  public func deleteTag(name: String) throws
  {
    try performWriting {
      let result = git_tag_delete(gitRepo, name)
      
      try RepoError.throwIfGitError(result)
    }
  }
}
