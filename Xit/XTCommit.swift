import Cocoa


public protocol CommitType: CustomStringConvertible {
  var SHA: String? { get }
  var parentSHAs: [String] { get }
  
  var message: String? { get }
  var commitDate: NSDate { get }
  var email: String? { get }
}

extension CommitType {
  public var description: String
  { return "\(SHA?.firstSix() ?? "-")" }
}


class XTCommit: CommitType {

  let gtCommit: GTCommit

  lazy var SHA: String? = self.calculateSHA()

  lazy var parentSHAs: [String] = self.calculateParentSHAs()
  
  var message: String?
  { return gtCommit.message }
  
  var commitDate: NSDate
  { return gtCommit.commitDate }
  
  var email: String?
  { return gtCommit.author?.email }

  init?(sha: String, repository: XTRepository)
  {
    guard let oid = GTOID(SHA: sha)
    else { return nil }
    
    var gitCommit: COpaquePointer = nil  // git_commit isn't imported
    let result = git_commit_lookup(&gitCommit,
                                   repository.gtRepo.git_repository(),
                                   oid.git_oid())
  
    guard result == 0,
          let commit = GTCommit(obj: gitCommit, inRepository: repository.gtRepo)
    else { return nil }
    
    self.gtCommit = commit
  }
  
  func calculateParentSHAs() -> [String]
  {
    var result = [String]()
    
    for index in 0..<git_commit_parentcount(gtCommit.git_commit()) {
      let parentID = git_commit_parent_id(gtCommit.git_commit(), index)
      guard parentID != nil
      else { continue }
      
      result.append(GTOID(gitOid:parentID).SHA)
    }
    return result
  }
  
  func calculateSHA() -> String?
  {
    return gtCommit.SHA
  }
}
