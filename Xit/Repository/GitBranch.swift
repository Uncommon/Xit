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
  { return name.removingPrefix(prefix) }
}


public protocol LocalBranch: Branch
{
  var trackingBranchName: String? { get set }
  var trackingBranch: RemoteBranch? { get }
}

extension LocalBranch
{
  public var prefix: String { return BranchPrefixes.heads }
}


public protocol RemoteBranch: Branch
{
  var remoteName: String? { get }
}

extension RemoteBranch
{
  public var prefix: String
  { return "\(BranchPrefixes.remotes)\(remoteName ?? "")/" }
}


public struct BranchPrefixes
{
  static let remotes = "refs/remotes/"
  static let heads = "refs/heads/"
}


public class GitBranch
{
  let branchRef: OpaquePointer
  
  required public init(branch: OpaquePointer)
  {
    self.branchRef = branch
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
  
  init?(repository: XTRepository, name: String)
  {
    guard let branch = GitBranch.lookUpBranch(
        name: name, repository: repository.gitRepo,
        branchType: GIT_BRANCH_LOCAL)
    else { return nil }
    
    super.init(branch: branch)
  }
  
  // Apparently just needed to disambiguate the overload
  required public init(branch: OpaquePointer)
  {
    super.init(branch: branch)
  }
  
  /// The name of this branch's remote tracking branch, even if the
  /// referenced branch does not exist.
  public var trackingBranchName: String?
  {
    get
    {
      guard !name.isEmpty,
            let repo = git_reference_owner(branchRef)
      else { return nil }
      let buf = UnsafeMutablePointer<git_buf>.allocate(capacity: 1)
    
      buf.pointee.size = 0
      buf.pointee.asize = 0
      guard git_branch_upstream_name(buf, repo, name) == 0
      else { return nil }
      
      let data = Data(bytes: buf.pointee.ptr, count: buf.pointee.size)
      
      git_buf_free(buf)
      return String(data: data, encoding: .utf8)?
             .removingPrefix(BranchPrefixes.remotes)
    }
    set
    {
      git_branch_set_upstream(branchRef, newValue)
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
    
    return GitRemoteBranch(branch: branch)
  }
  
  override var remoteName: String?
  {
    return trackingBranch?.remoteName
  }
}

public class GitRemoteBranch: GitBranch, RemoteBranch
{
  public var shortName: String
  { return name.removingPrefix(BranchPrefixes.remotes) }

  init?(repository: XTRepository, name: String)
  {
    guard let branch = GitBranch.lookUpBranch(
        name: name, repository: repository.gitRepo,
        branchType: GIT_BRANCH_REMOTE)
    else { return nil }
    
    super.init(branch: branch)
  }
  
  required public init(branch: OpaquePointer)
  {
    super.init(branch: branch)
  }
  
  public override var remoteName: String?
  {
    let repo = git_reference_owner(branchRef)
    let buffer = UnsafeMutablePointer<git_buf>.allocate(capacity: 1)
    
    buffer.pointee = git_buf(ptr: nil, asize: 0, size: 0)
    
    let result = git_branch_remote_name(buffer, repo, name)
    
    guard result == 0
    else { return nil }
    
    let data = Data(bytes: buffer.pointee.ptr, count: buffer.pointee.size)
    
    return String(data: data, encoding: .utf8)
  }
}
