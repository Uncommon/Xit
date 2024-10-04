import Foundation
import Combine

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
  public var currentBranch: LocalBranchRefName?
  {
    mutex.withLock {
      if currentBranchSubject.value == nil {
        refsChanged()
      }
      return currentBranchSubject.value.flatMap { .init($0) }
    }
  }

  public var currentBranchPublisher: AnyPublisher<String?, Never>
  { currentBranchSubject.eraseToAnyPublisher() }
  
  public var localBranches: AnySequence<GitLocalBranch>
  { AnySequence { LocalBranchIterator(repo: self) } }
  
  public var remoteBranches: AnySequence<GitRemoteBranch>
  { AnySequence { RemoteBranchIterator(repo: self) } }

  public func createBranch(named name: String,
                           target: String) throws -> GitLocalBranch?
  {
    if isWriting {
      throw RepoError.alreadyWriting
    }

    guard let targetRef = GitReference(name: target,
                                       repository: gitRepo),
          let targetOID = targetRef.targetOID,
          let targetCommit = GitCommit(oid: targetOID, repository: gitRepo)
    else { return nil }
    
    let branchRef = try OpaquePointer.from {
      git_branch_create(&$0, gitRepo, name, targetCommit.commit, 0)
    }
    
    return GitLocalBranch(branch: branchRef, config: config)
  }
  
  /// Renames the given local branch.
  public func rename(branch: String, to newName: String) throws
  {
    if isWriting {
      throw RepoError.alreadyWriting
    }
    
    let branchRef = try OpaquePointer.from {
      git_branch_lookup(&$0, gitRepo, branch, GIT_BRANCH_LOCAL)
    }
    var newRef: OpaquePointer? = nil
    let result = git_branch_move(&newRef, branchRef, newName, 0)
    
    try RepoError.throwIfGitError(result)
  }

  public func localBranch(named refName: LocalBranchRefName) -> GitLocalBranch?
  {
    let fullName = refName.fullPath
    
    if let branch = cachedBranches[fullName] as? GitLocalBranch {
      return branch
    }
    else {
      guard let branch = GitLocalBranch(repository: gitRepo,
                                        name: refName.name,
                                        config: config)
      else { return nil }
      
      addCachedBranch(branch)
      return branch
    }
  }
  
  public func remoteBranch(named name: String,
                           remote: String) -> GitRemoteBranch?
  {
    return remoteBranch(named: remote +/ name)
  }
  
  public func remoteBranch(named name: String) -> GitRemoteBranch?
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
  
  public func localBranch(tracking remoteBranch: GitRemoteBranch)
    -> GitLocalBranch?
  {
    return localTrackingBranch(forBranch: remoteBranch.referenceName)
  }
  
  // swiftlint:disable:next force_try
  static let remoteRegex = try!
      NSRegularExpression(pattern: "\\Abranch\\.(.*)\\.remote",
                          options: [])

  public func localTrackingBranch(forBranch branchRef: RemoteBranchRefName)
    -> GitLocalBranch?
  {
    let config = self.config as! GitConfig
    
    // Looping through all the branches can be expensive
    for entry in config.entries {
      let name = entry.name
      guard let match = XTRepository.remoteRegex
                                    .firstMatch(in: name, options: [],
                                                range: name.fullNSRange),
            match.numberOfRanges == 2,
            let branchRange = Range(match.range(at: 1), in: name),
            entry.stringValue == branchRef.remoteName
      else { continue }
      let entryBranch = String(name[branchRange])
      guard let mergeName = config.branchMerge(entryBranch)
      else { continue }

      let expectedMergeName = RefPrefixes.heads +/ branchRef.localName
      
      if mergeName == expectedMergeName,
         let refName = LocalBranchRefName(entryBranch) {
        return localBranch(named: refName)
      }
    }
    return nil
  }
  
  public func reset(toCommit target: any Xit.Commit, mode: ResetMode) throws
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
  public func tag(named name: String) -> GitTag?
  {
    GitTag(repository: self, name: name)
  }

  public func createTag(name: String, targetOID: GitOID, message: String?) throws
  {
    try performWriting {
      guard let commit = GitCommit(oid: targetOID,
                                   repository: gitRepo)
      else { throw RepoError.notFound }
      
      var oid = git_oid()
      guard let defaultSig = GitSignature(defaultFromRepo: gitRepo)
      else { throw RepoError.unexpected }
      
      let result = git_tag_create(&oid, gitRepo, name,
                                  commit.commit, defaultSig.signature,
                                  message, 0)
      
      try RepoError.throwIfGitError(result)
    }
  }
  
  public func createLightweightTag(name: String, targetOID: GitOID) throws
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
