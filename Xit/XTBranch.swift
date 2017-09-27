import Cocoa

public protocol Branch
{
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
  var trackingBranchName: String? { get }
  var trackingBranch: RemoteBranch? { get }
}

extension LocalBranch
{
  var strippedName: String?
  {
    return name.removingPrefix(XTLocalBranch.headsPrefix)
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


public class XTBranch: Branch
{
  let gtBranch: GTBranch
  
  required public init(gtBranch: GTBranch)
  {
    self.gtBranch = gtBranch
  }
  
  convenience init?(name: String, repository: XTRepository)
  {
    do {
      self.init(gtBranch: try repository.gtRepo.currentBranch())
    }
    catch {
      return nil
    }
  }
  
  public var name: String { return gtBranch.name ?? "" }
  public var oid: OID?
  {
    return gtBranch.oid.map { GitOID(oid: $0.git_oid().pointee) }
  }

  var sha: String? { return gtBranch.oid?.sha }
  var targetCommit: XTCommit?
  {
    return (try? gtBranch.targetCommit()).map { XTCommit(commit: $0) }
  }
  var reference: GTReference
  {
    return gtBranch.reference
  }
  var remoteName: String? { return nil }
}

public class XTLocalBranch: XTBranch, LocalBranch
{
  static let trackingPrefix = "refs/remotes/"
  static let headsPrefix = "refs/heads/"
  
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
      guard !name.isEmpty
      else { return nil }
      let buf = UnsafeMutablePointer<git_buf>.allocate(capacity: 1)
    
      buf.pointee.size = 0
      buf.pointee.asize = 0
      if git_branch_upstream_name(buf, gtBranch.repository.git_repository(),
                                  name) != 0 {
        return nil
      }
      
      let data = Data(bytes: buf.pointee.ptr, count: buf.pointee.size)
      
      git_buf_free(buf)
      return String(data: data, encoding: .utf8)?
             .removingPrefix(XTLocalBranch.trackingPrefix)
    }
    set
    {
      git_branch_set_upstream(gtBranch.reference.git_reference(),
                              newValue?.withPrefix(XTLocalBranch.trackingPrefix))
    }
  }
  
  /// Returns a branch object for this branch's remote tracking branch,
  /// or `nil` if no tracking branch is set or if it references a non-existent
  /// branch.
  public var trackingBranch: RemoteBranch?
  {
    guard let branch = gtBranch.trackingBranchWithError(nil, success: nil)
    else { return nil }
    
    return XTRemoteBranch(gtBranch: branch)
  }
  
  override var remoteName: String?
  {
    return trackingBranch?.remoteName
  }
}

public class XTRemoteBranch: XTBranch, RemoteBranch
{
  static let remotesPrefix = "refs/remotes/"

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
