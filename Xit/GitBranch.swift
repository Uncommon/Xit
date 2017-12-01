import Cocoa

public protocol Branch
{
  /// The full reference name
  var name: String { get }
  /// Same as branch name, but without remote name for remote branches
  var shortName: String { get }
  /// The ref name without the refs/.../ prefix
  var strippedName: String { get }
  var oid: OID? { get }
}

extension Branch
{
  public var shortName: String
  {
    return strippedName
  }
  public var strippedName: String
  {
    return name.components(separatedBy: "/").dropFirst(2).joined(separator: "/")
  }
}


public protocol LocalBranch: Branch
{
  var trackingBranchName: String? { get set }
  var trackingBranch: RemoteBranch? { get }
}

extension LocalBranch
{
  var strippedName: String?
  {
    return name.removingPrefix(BranchPrefixes.heads)
  }
}


public protocol RemoteBranch: Branch
{
  var remoteName: String? { get }
}

extension RemoteBranch
{
  public var shortName: String
  {
    guard let slashIndex = name.index(of: "/").map({ name.index(after: $0) })
      else { return name }
    
    return String(name[slashIndex...])
  }
  public var strippedName: String
  {
    return name.components(separatedBy: "/").dropFirst(3).joined(separator: "/")
  }
}


public struct BranchPrefixes
{
  static let remotes = "refs/remotes/"
  static let heads = "refs/heads/"
}


public class GitBranch: Branch
{
  let gtBranch: GTBranch
  let branch: OpaquePointer
  
  required public init(gtBranch: GTBranch)
  {
    self.gtBranch = gtBranch
    self.branch = gtBranch.reference.git_reference()
  }
  
  public var name: String
  {
    guard let name = git_reference_name(branch)
    else { return "" }
    
    return String(cString: name)
  }
  
  public var oid: OID?
  {
    guard let oid = git_reference_target(branch)
    else { return nil }
    
    return GitOID(oidPtr: oid)
  }

  var sha: String? { return oid?.sha }
  var targetCommit: XTCommit?
  {
    guard let oid = oid,
          let repo = git_reference_owner(branch)
    else { return nil }
    
    return XTCommit(oid: oid, repository: repo)
  }
  var remoteName: String? { return nil }
}

public class GitLocalBranch: GitBranch, LocalBranch
{
  init?(repository: XTRepository, name: String)
  {
    guard let gtBranch = try? repository.gtRepo.lookUpBranch(
        withName: name, type: .local, success: nil)
    else { return nil }
    
    super.init(gtBranch: gtBranch)
  }
  
  // Apparently just needed to disambiguate the overload
  required public init(gtBranch: GTBranch)
  {
    super.init(gtBranch: gtBranch)
  }
  
  /// The name of this branch's remote tracking branch, even if the
  /// referenced branch does not exist.
  public var trackingBranchName: String?
  {
    get
    {
      guard !name.isEmpty,
            let repo = git_reference_owner(branch)
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
      git_branch_set_upstream(branch,
                              newValue?.withPrefix(BranchPrefixes.remotes))
    }
  }
  
  /// Returns a branch object for this branch's remote tracking branch,
  /// or `nil` if no tracking branch is set or if it references a non-existent
  /// branch.
  public var trackingBranch: RemoteBranch?
  {
    guard let branch = gtBranch.trackingBranchWithError(nil, success: nil)
    else { return nil }
    
    return GitRemoteBranch(gtBranch: branch)
  }
  
  override var remoteName: String?
  {
    return trackingBranch?.remoteName
  }
}

public class GitRemoteBranch: GitBranch, RemoteBranch
{
  init?(repository: XTRepository, name: String)
  {
    guard let gtBranch = try? repository.gtRepo.lookUpBranch(withName: name,
                                                             type: .remote,
                                                             success: nil)
    else { return nil }
    
    super.init(gtBranch: gtBranch)
  }
  
  required public init(gtBranch: GTBranch)
  {
    super.init(gtBranch: gtBranch)
  }
  
  public override var remoteName: String? { return gtBranch.remoteName }
}
