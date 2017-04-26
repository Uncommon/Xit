import Cocoa


public protocol CommitType: CustomStringConvertible
{
  associatedtype ID: OID
  
  var sha: String? { get }
  var oid: ID { get }
  var parentOIDs: [ID] { get }
  
  var message: String? { get }
  var authorName: String? { get }
  var authorEmail: String? { get }
  var authorDate: Date? { get }
  var committerName: String? { get }
  var committerEmail: String? { get }
  var commitDate: Date { get }
  var email: String? { get }
}

extension CommitType
{
  public var parentSHAs: [String]
  {
    return parentOIDs.flatMap { $0.sha }
  }
  
  public var messageSummary: String
  {
    guard let message = message
    else { return "" }
    
    return message.range(of: "\n").map {
      message.substring(to: $0.lowerBound)
    } ?? message
  }

  public var description: String
  { return "\(sha?.firstSix() ?? "-")" }
}


public func == (a: GTOID, b: GTOID) -> Bool
{
  return git_oid_cmp(a.git_oid(), b.git_oid()) == 0
}


public class XTCommit: CommitType
{
  let gtCommit: GTCommit
  
  // These used to be lazy properties, but the Swift 3 compiler crashes on that.
  let cachedSHA: String?
  let cachedOID: GitOID
  let cachedParentOIDs: [GitOID]

  public var sha: String? { return cachedSHA }
  public var oid: GitOID { return cachedOID }

  public var parentOIDs: [GitOID] { return cachedParentOIDs }
  
  public var message: String?
  { return gtCommit.message }
  
  public var messageSummary: String
  { return gtCommit.messageSummary }
  
  public var authorSig: GitSignature?
  {
    guard let sig = git_commit_author(gtCommit.git_commit())
    else { return nil }
    
    return GitSignature(signature: sig.pointee)
  }
  
  public var authorName: String?
  { return gtCommit.author?.name }
  
  public var authorEmail: String?
  { return gtCommit.author?.email }
  
  public var authorDate: Date?
  { return gtCommit.author?.time }
  
  public var committerSig: GitSignature?
  {
    guard let sig = git_commit_committer(gtCommit.git_commit())
    else { return nil }
    
    return GitSignature(signature: sig.pointee)
  }
  
  public var committerName: String?
  { return gtCommit.committer?.name }
  
  public var committerEmail: String?
  { return gtCommit.committer?.email }
  
  public var commitDate: Date
  { return gtCommit.commitDate }
  
  public var email: String?
  { return gtCommit.author?.email }

  public var tree: GTTree?
  { return gtCommit.tree }

  init(commit: GTCommit)
  {
    self.gtCommit = commit
    self.cachedSHA = commit.sha
    self.cachedOID = GitOID(oid: commit.oid!.git_oid().pointee)
    self.cachedParentOIDs = XTCommit.calculateParentOIDs(gtCommit.git_commit())
  }

  convenience init?(oid: GitOID, repository: XTRepository)
  {
    var gitCommit: OpaquePointer?  // git_commit isn't imported
    let result = git_commit_lookup(&gitCommit,
                                   repository.gtRepo.git_repository(),
                                   oid.unsafeOID())
  
    guard result == 0,
          let commit = GTCommit(obj: gitCommit!, in: repository.gtRepo)
    else { return nil }
    
    self.init(commit: commit)
  }
  
  convenience init?(sha: String, repository: XTRepository)
  {
    guard let oid = GitOID(sha: sha)
    else { return nil }
    
    self.init(oid: oid, repository: repository)
  }
  
  convenience init?(ref: String, repository: XTRepository)
  {
    let gitRefPtr = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
    guard git_reference_lookup(gitRefPtr,
                               repository.gtRepo.git_repository(),
                               ref) == 0,
          let gitRef = gitRefPtr.pointee
    else { return nil }
    
    let gitObjectPtr = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
    guard git_reference_peel(gitObjectPtr, gitRef, GIT_OBJ_COMMIT) == 0,
          let gitObject = gitObjectPtr.pointee,
          let commit = GTCommit(obj: gitObject, in: repository.gtRepo)
    else { return nil }
    
    self.init(commit: commit)
  }
  
  /// Returns a list of all files in the commit's tree, with paths relative
  /// to the root.
  func allFiles() -> [String]
  {
    guard let tree = tree
    else { return [] }
    
    var result = [String]()
    
    _ = try? tree.enumerateEntries(with: .pre) {
      (entry, root, _) -> Bool in
      result.append(root.appending(pathComponent: entry.name))
      return true
    }
    return result
  }
  
  private static func calculateParentOIDs(_ rawCommit: OpaquePointer) -> [GitOID]
  {
    var result = [GitOID]()
    
    for index in 0..<git_commit_parentcount(rawCommit) {
      let parentID = git_commit_parent_id(rawCommit, index)
      guard parentID != nil
      else { continue }
      
      result.append(GitOID(oidPtr: parentID!))
    }
    return result
  }
  
  private func calculateSHA() -> String?
  {
    return gtCommit.sha
  }
  
  private func calculateOID() -> GTOID
  {
    return gtCommit.oid!
  }
}

public func == (a: XTCommit, b: XTCommit) -> Bool
{
  return a.oid == b.oid
}
