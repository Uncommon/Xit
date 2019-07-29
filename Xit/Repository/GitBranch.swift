import Cocoa

public protocol Branch: AnyObject
{
  /// The full reference name
  var name: String { get }
  /// Like `strippedName` but including the remote name for remote branches
  var shortName: String { get }
  /// The name without `prefix`
  var strippedName: String { get }
  /// Text that is not part of the specific branch name
  var prefix: String { get }
  /// OID of the branch's head commit
  var oid: OID? { get }
  /// The branch's head commit
  var targetCommit: Commit? { get }
}

extension Branch
{
  public var strippedName: String
  { return name.droppingPrefix(prefix) }
}


public protocol LocalBranch: Branch
{
  var trackingBranchName: String? { get set }
  var trackingBranch: RemoteBranch? { get }
}

extension LocalBranch
{
  public var prefix: String { return RefPrefixes.heads }
}


public protocol RemoteBranch: Branch
{
  var remoteName: String? { get }
}

extension RemoteBranch
{
  public var prefix: String
  { return "\(RefPrefixes.remotes)\(remoteName ?? "")/" }
  
  /// What the branch name would look like if it were a local branch
  public var localBranchName: String
  { return RefPrefixes.heads + strippedName }
}


public enum RefPrefixes
{
  static let remotes = "refs/remotes/"
  static let heads = "refs/heads/"
  static let tags = "refs/tags/"
}


public class GitBranch
{
  let branchRef: OpaquePointer
  let config: Config
  
  required public init(branch: OpaquePointer, config: Config)
  {
    self.branchRef = branch
    self.config = config
  }

  public var name: String
  {
    guard let name = git_reference_name(branchRef)
    else { return "" }
    
    return String(cString: name)
  }
  
  public var oid: OID?
  {
    guard let oid = git_reference_target(branchRef)
    else { return nil }
    
    return GitOID(oidPtr: oid)
  }

  var sha: String? { return oid?.sha }
  public var targetCommit: Commit?
  {
    guard let oid = oid,
          let repo = git_reference_owner(branchRef)
    else { return nil }
    
    return GitCommit(oid: oid, repository: repo)
  }
  var remoteName: String? { return nil }
  
  fileprivate static func lookUpBranch(name: String, repository: OpaquePointer,
                                       branchType: git_branch_t)
    -> OpaquePointer?
  {
    let branch = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
    let result = git_branch_lookup(branch, repository,
                                   name, branchType)
    guard result == 0,
          let finalBranch = branch.pointee
    else { return nil }
    
    return finalBranch
  }
}

public class GitLocalBranch: GitBranch, LocalBranch
{
  public var shortName: String { return strippedName }
  
  init?(repository: OpaquePointer, name: String, config: Config)
  {
    guard let branch = GitBranch.lookUpBranch(name: name,
                                              repository: repository,
                                              branchType: GIT_BRANCH_LOCAL)
    else { return nil }
    
    super.init(branch: branch, config: config)
  }
  
  // Apparently just needed to disambiguate the overload
  required public init(branch: OpaquePointer, config: Config)
  {
    super.init(branch: branch, config: config)
  }
  
  /// The name of this branch's remote tracking branch, even if the
  /// referenced branch does not exist.
  public var trackingBranchName: String?
  {
    get
    {
      // Re-implement `git_branch_upstream_name` but with our cached-snapshot
      // config optimization.
      let name = self.shortName
      guard let remoteName = config.branchRemote(name),
            let mergeName = config.branchMerge(name)
      else { return nil }
      
      if remoteName == "." {
        return mergeName
      }
      else {
        guard let repo = git_reference_owner(branchRef),
              let remote = GitRemote(name: remoteName, repository: repo),
              let refSpec = remote.refSpecs.first(where: {
                (spec) in
                spec.direction == .fetch && spec.sourceMatches(refName: mergeName)
              })
        else { return nil }
        
        return refSpec.transformToTarget(name: mergeName)?
                      .droppingPrefix(RefPrefixes.remotes)
      }
    }
    set
    {
      git_branch_set_upstream(branchRef, newValue)
      (config as? GitConfig)?.loadSnapshot()
    }
  }
  
  /// Returns a branch object for this branch's remote tracking branch,
  /// or `nil` if no tracking branch is set or if it references a non-existent
  /// branch.
  public var trackingBranch: RemoteBranch?
  {
    let upstream = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
    let result = git_branch_upstream(upstream, branchRef)
    
    guard result == 0,
          let branch = upstream.pointee
    else { return nil }
    
    return GitRemoteBranch(branch: branch, config: config)
  }
  
  override var remoteName: String?
  {
    return trackingBranch?.remoteName
  }
}

public class GitRemoteBranch: GitBranch, RemoteBranch
{
  public var shortName: String
  { return name.droppingPrefix(RefPrefixes.remotes) }

  // Getting the remote name involves looking it up in the config file
  // which is a bit expensive
  private lazy var cachedRemoteName: String? = {
    () -> String? in
    let repo = git_reference_owner(branchRef)
    let buffer = UnsafeMutablePointer<git_buf>.allocate(capacity: 1)
    
    buffer.pointee = git_buf(ptr: nil, asize: 0, size: 0)
    
    let result = git_branch_remote_name(buffer, repo, name)
    
    guard result == 0
    else { return nil }
    
    let data = Data(bytes: buffer.pointee.ptr, count: buffer.pointee.size)
    
    return String(data: data, encoding: .utf8)
  }()
  
  public override var remoteName: String? { return cachedRemoteName }

  init?(repository: OpaquePointer, name: String, config: Config)
  {
    guard let branch = GitBranch.lookUpBranch(
        name: name, repository: repository,
        branchType: GIT_BRANCH_REMOTE)
    else { return nil }
    
    super.init(branch: branch, config: config)
  }
  
  required public init(branch: OpaquePointer, config: Config)
  {
    super.init(branch: branch, config: config)
  }
}
