import Cocoa


protocol CommitType {
  var SHA: String? { get }
  var parentSHAs: [String] { get }
  
  var message: String? { get }
  var commitDate: NSDate { get }
  var email: String? { get }
}


class XTCommit: CommitType {

  let gtCommit: GTCommit

  var SHA: String?
  { return gtCommit.SHA }

  var parentSHAs: [String]
  { return gtCommit.parents.flatMap({ $0.SHA }) }
  
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
}
