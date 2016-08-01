import Cocoa


protocol CommitType {
  var SHA: String? { get }
  var parentSHAs: [String] { get }
}


class XTCommit: GTCommit, CommitType {

  var parentSHAs: [String]
  {
    return parents.flatMap({ $0.SHA })
  }

  init?(sha: String, repository: XTRepository)
  {
    guard let oid = GTOID(SHA: sha)
    else { return nil }
    
    var gitCommit: COpaquePointer = nil  // git_commit isn't imported
    let result = git_commit_lookup(&gitCommit,
                                   repository.gtRepo.git_repository(),
                                   oid.git_oid())
  
    guard result == 0
    else { return nil }
    
    super.init(obj: gitCommit, inRepository: repository.gtRepo)
  }
}
