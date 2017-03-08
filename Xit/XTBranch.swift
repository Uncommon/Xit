import Cocoa

public class XTBranch
{
  let gtBranch: GTBranch
  
  required public init(gtBranch: GTBranch)
  {
    self.gtBranch = gtBranch
  }
  
  var name: String? { return gtBranch.name }
  var shortName: String? { return gtBranch.shortName }
  var sha: String? { return gtBranch.oid?.sha }
  var oid: GitOID?
  {
    return gtBranch.oid.map { GitOID(oid: $0.git_oid().pointee) }
  }
}

public class XTLocalBranch: XTBranch
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
  
  /// Returns the name of this branch's remote tracking branch, even if the
  /// referenced branch does not exist.
  var trackingBranchName: String?
  {
    guard let name = self.name
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
    return String(data: data, encoding: .utf8)
  }
  
  /// Returns a branch object for this branch's remote tracking branch,
  /// or `nil` if no tracking branch is set or if it references a non-existent
  /// branch.
  var trackingBranch: XTRemoteBranch?
  {
    guard let branch = gtBranch.trackingBranchWithError(nil, success: nil)
    else { return nil }
    
    return XTRemoteBranch(gtBranch: branch)
  }
}

public class XTRemoteBranch: XTBranch
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
  
  var remoteName: String { return gtBranch.remoteName ?? "" }
  override var shortName: String? { return gtBranch.shortName }
}
