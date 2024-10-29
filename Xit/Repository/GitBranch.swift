import Cocoa
import FakedMacro

@Faked(skip: ["localRefName", "remoteName"], createNull: false)
public protocol Branch: AnyObject, PathTreeData
{
  associatedtype BranchRefName: ReferenceName

  var referenceName: BranchRefName { get }
  /// If a remote branch, then the local counterpart (removing the remote name).
  /// Otherwise the same as `referenceName`.
  var localRefName: LocalBranchRefName { get }
  /// OID of the branch's head commit
  var oid: GitOID? { get }
  /// The branch's head commit
  var targetCommit: (any Commit)? { get }
  /// The remote this branch relates to. If a remote branch, then that remote.
  /// Otherwise the remote for the tracking branch, if any.
  var remoteName: String? { get }
}

extension Branch // PathTreeData
{
  public var treeNodePath: String { referenceName.fullPath }
}

@Faked(skip: ["shortName"], anyObject: true, inherit: ["EmptyBranch"])
public protocol LocalBranch: Branch
  where BranchRefName == LocalBranchRefName
{
  associatedtype RemoteBranch: Xit.RemoteBranch

  /// Can be a `LocalBranchRefName` or a `RemoteBranchRefName` depeding on
  /// the configuration.
  var trackingBranchName: (any ReferenceName)? { get set }
  var trackingBranch: RemoteBranch? { get }
}

extension LocalBranch
{
  public var localRefName: LocalBranchRefName { referenceName }
  public var remoteName: String? { trackingBranch?.remoteName }
  public var remoteTrackingBranchName: RemoteBranchRefName?
  { trackingBranchName as? RemoteBranchRefName }
}


@Faked(anyObject: true, inherit: ["EmptyBranch"])
public protocol RemoteBranch: Branch
  where BranchRefName == RemoteBranchRefName
{
}
extension EmptyRemoteBranch
{
  public var shortName: String { "" }
}

extension RemoteBranch
{
  public var localRefName: LocalBranchRefName
  { .init(rawValue: RefPrefixes.heads + referenceName.localName)! }
}

// EmptyRemoteBranch can't be extended outside the macro
extension RemoteBranch
{
  public var remoteName: String? { nil }
}


public enum RefPrefixes
{
  public static let remotes = "refs/remotes/"
  public static let heads = "refs/heads/"
  public static let tags = "refs/tags/"
}


public class GitBranch
{
  let branchRef: OpaquePointer
  let config: any Config
  
  required public init(branch: OpaquePointer, config: any Config)
  {
    self.branchRef = branch
    self.config = config
  }

  deinit
  {
    git_reference_free(branchRef)
  }

  /// The full branch name including "refs/heads/"
  public var name: String
  {
    guard let name = git_reference_name(branchRef)
    else { return "" }
    
    return String(cString: name)
  }
  
  public var oid: GitOID?
  {
    guard let oid = git_reference_target(branchRef)
    else { return nil }
    
    return GitOID(oidPtr: oid)
  }

  var sha: String? { oid?.sha }
  public var targetCommit: (any Commit)?
  {
    guard let oid = oid,
          let repo = git_reference_owner(branchRef)
    else { return nil }
    
    return GitCommit(oid: oid, repository: repo)
  }

  fileprivate static func lookUpBranch(name: String,
                                       repository: OpaquePointer,
                                       branchType: git_branch_t)
    -> OpaquePointer?
  {
    return try? OpaquePointer.from {
      git_branch_lookup(&$0, repository, name, branchType)
    }
  }
}

public final class GitLocalBranch: GitBranch, LocalBranch
{
  public var referenceName: LocalBranchRefName { .init(rawValue: name)! }

  init?(repository: OpaquePointer, name: String, config: any Config)
  {
    guard let branch = GitBranch.lookUpBranch(name: name,
                                              repository: repository,
                                              branchType: GIT_BRANCH_LOCAL)
    else { return nil }
    
    super.init(branch: branch, config: config)
  }
  
  // Apparently just needed to disambiguate the overload
  required public init(branch: OpaquePointer, config: any Config)
  {
    super.init(branch: branch, config: config)
  }
  
  /// The name of this branch's remote tracking branch, even if the
  /// referenced branch does not exist.
  public var trackingBranchName: (any ReferenceName)?
  {
    get
    {
      // Re-implement `git_branch_upstream_name` but with our cached-snapshot
      // config optimization.
      let name = referenceName.name
      guard let remoteName = config.branchRemote(name),
            let mergeName = config.branchMerge(name)
      else { return nil }
      
      if remoteName == "." {
        return LocalBranchRefName(mergeName)
      }
      else {
        guard let repo = git_reference_owner(branchRef),
              let remote = GitRemote(name: remoteName, repository: repo),
              let refSpec = remote.refSpecs.first(where: {
                (spec) in
                spec.direction == .fetch && spec.sourceMatches(refName: mergeName)
              })
        else { return nil }
        
        return refSpec.transformToTarget(name: mergeName).flatMap {
          RemoteBranchRefName($0)
        }
      }
    }
    set
    {
      git_branch_set_upstream(branchRef, newValue?.fullPath)
      (config as? GitConfig)?.loadSnapshot()
    }
  }
  
  /// Returns a branch object for this branch's remote tracking branch,
  /// or `nil` if no tracking branch is set or if it references a non-existent
  /// branch.
  public var trackingBranch: GitRemoteBranch?
  {
    guard let upstream = try? OpaquePointer.from({
      git_branch_upstream(&$0, branchRef)
    })
    else { return nil }
    
    return GitRemoteBranch(branch: upstream, config: config)
  }
}

public final class GitRemoteBranch: GitBranch, RemoteBranch
{
  public var referenceName: RemoteBranchRefName { .init(rawValue: name)! }

  public var remoteName: String?
  { name.droppingPrefix(RefPrefixes.remotes).firstPathComponent }

  init?(repository: OpaquePointer, name: String, config: any Config)
  {
    guard let branch = GitBranch.lookUpBranch(
        name: name, repository: repository,
        branchType: GIT_BRANCH_REMOTE)
    else { return nil }
    
    super.init(branch: branch, config: config)
  }
  
  required public init(branch: OpaquePointer, config: any Config)
  {
    super.init(branch: branch, config: config)
  }
}
