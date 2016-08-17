import Cocoa


public protocol CommitType: CustomStringConvertible {
  var SHA: String? { get }
  var OID: GTOID { get }
  var parentOIDs: [GTOID] { get }
  
  var message: String? { get }
  var commitDate: NSDate { get }
  var email: String? { get }
}

extension CommitType {
  public var description: String
  { return "\(SHA?.firstSix() ?? "-")" }
}


public func == (a: GTOID, b: GTOID) -> Bool
{
  return git_oid_cmp(a.git_oid(), b.git_oid()) == 0
}


public class XTCommit: CommitType {

  let gtCommit: GTCommit

  lazy public var SHA: String? = self.calculateSHA()
  lazy public var OID: GTOID = self.calculateOID()

  lazy public var parentOIDs: [GTOID] = self.calculateParentOIDs()
  
  public var message: String?
  { return gtCommit.message }
  
  public var commitDate: NSDate
  { return gtCommit.commitDate }
  
  public var email: String?
  { return gtCommit.author?.email }

  init?(oid: GTOID, repository: XTRepository)
  {
    var gitCommit: COpaquePointer = nil  // git_commit isn't imported
    let result = git_commit_lookup(&gitCommit,
                                   repository.gtRepo.git_repository(),
                                   oid.git_oid())
  
    guard result == 0,
          let commit = GTCommit(obj: gitCommit, inRepository: repository.gtRepo)
    else { return nil }
    
    self.gtCommit = commit
  }
  
  convenience init?(sha: String, repository: XTRepository)
  {
    guard let oid = GTOID(SHA: sha)
    else { return nil }
    
    self.init(oid: oid, repository: repository)
  }
  
  func calculateParentOIDs() -> [GTOID]
  {
    var result = [GTOID]()
    
    for index in 0..<git_commit_parentcount(gtCommit.git_commit()) {
      let parentID = git_commit_parent_id(gtCommit.git_commit(), index)
      guard parentID != nil
      else { continue }
      
      result.append(GTOID(gitOid:parentID))
    }
    return result
  }
  
  func calculateSHA() -> String?
  {
    return gtCommit.SHA
  }
  
  func calculateOID() -> GTOID
  {
    return gtCommit.OID!
  }
}

public func == (a: XTCommit, b: XTCommit) -> Bool
{
  return git_oid_cmp(a.OID.git_oid(), b.OID.git_oid()) == 0
}
