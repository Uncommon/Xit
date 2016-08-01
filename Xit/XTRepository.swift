import Foundation


protocol RepositoryType {
  func commit(forSHA sha: String) -> CommitType?
}


extension XTRepository: RepositoryType {
  
  func commit(forSHA sha: String) -> CommitType?
  {
    return XTCommit(sha: sha, repository: self)
  }
}
