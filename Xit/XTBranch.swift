import Cocoa

class XTBranch: NSObject {

  private let gtBranch: GTBranch
  
  init(gtBranch: GTBranch)
  {
    self.gtBranch = gtBranch
  }
  
  var name: String? { return gtBranch.name }
  var shortName: String? { return name }
}

class XTLocalBranch: XTBranch {
  
  init?(repository: XTRepository, name: String)
  {
    guard let gtBranch = try? repository.gtRepo.lookUpBranchWithName(
        name, type: .Local, success: nil)
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

class XTRemoteBranch: XTBranch {
  
  init?(repository: XTRepository, name: String)
  {
    guard let gtBranch = try? repository.gtRepo.lookUpBranchWithName(
      name, type: .Remote, success: nil)
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
