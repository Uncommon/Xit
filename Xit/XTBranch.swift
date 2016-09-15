import Cocoa

public class XTBranch: NSObject {

  let gtBranch: GTBranch
  
  init(gtBranch: GTBranch)
  {
    self.gtBranch = gtBranch
  }
  
  var name: String? { return gtBranch.name }
  var shortName: String? { return name }
}

public class XTLocalBranch: XTBranch {
  
  init?(repository: XTRepository, name: String)
  {
    guard let gtBranch = try? repository.gtRepo.lookUpBranch(
        withName: name, type: .local, success: nil)
    else { return nil }
    
    super.init(gtBranch: gtBranch)
  }
  
  // Apparently just needed to disambiguate the overload
  override init(gtBranch: GTBranch)
  {
    super.init(gtBranch: gtBranch)
  }
  
  var trackingBranch: XTRemoteBranch?
  {
    guard let branch = gtBranch.trackingBranchWithError(nil, success: nil)
    else { return nil }
    
    return XTRemoteBranch(gtBranch: branch)
  }
}

public class XTRemoteBranch: XTBranch {
  
  init?(repository: XTRepository, name: String)
  {
    guard let gtBranch = try? repository.gtRepo.lookUpBranch(
      withName: name, type: .remote, success: nil)
      else { return nil }
    
    super.init(gtBranch: gtBranch)
  }
  
  override init(gtBranch: GTBranch)
  {
    super.init(gtBranch: gtBranch)
  }
  
  var remoteName: String { return gtBranch.remoteName ?? "" }
  override var shortName: String? { return gtBranch.shortName }
}
