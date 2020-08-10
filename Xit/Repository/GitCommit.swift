import Cocoa


public protocol Commit: OIDObject, CustomStringConvertible
{
  var sha: String { get }
  var parentOIDs: [OID] { get }
  
  var message: String? { get }
  
  var authorSig: Signature? { get }
  var committerSig: Signature? { get }
  
  var authorName: String? { get }
  var authorEmail: String? { get }
  var authorDate: Date? { get }
  var committerName: String? { get }
  var committerEmail: String? { get }
  var commitDate: Date { get }
  var email: String? { get }
  
  var tree: Tree? { get }
}

extension Commit
{
  public var sha: String { oid.sha }
  
  var authorName: String? { authorSig?.name }
  var authorEmail: String? { authorSig?.email }
  var authorDate: Date? { authorSig?.when }
  var committerName: String? { committerSig?.name }
  var committerEmail: String? { committerSig?.email }
  var commitDate: Date { committerSig?.when ?? Date() }
}

extension Commit
{
  public var parentSHAs: [String]
  { parentOIDs.compactMap { $0.sha } }
  
  public var messageSummary: String
  {
    guard let message = message
    else { return "" }
    
    return message.range(of: "\n").map {
      String(message[..<$0.lowerBound])
    } ?? message
  }

  public var description: String
  { sha.firstSix() }
}

public class GitCommit: Commit
{
  let commit: OpaquePointer
  let mutex = Mutex()
  var storedSHA: String?

  public var sha: String
  {
    mutex.withLock {
      if let sha = storedSHA {
        return sha
      }
      else {
        let result = oid.sha
        
        storedSHA = result
        return result
      }
    }
  }
  public let oid: OID
  public let parentOIDs: [OID]
  
  public var repository: OpaquePointer
  { git_commit_owner(commit) }
  
  public var message: String?
  {
    if let result = git_commit_message(commit) {
      return String(cString: result)
    }
    else {
      return nil
    }
  }
  
  public var messageSummary: String
  {
    guard let message = self.message
    else { return String() }
    
    if let lineEnd = message.rangeOfCharacter(from: .newlines) {
      return String(message[..<lineEnd.lowerBound])
    }
    else {
      return message
    }
  }
  
  public var authorSig: Signature?
  {
    guard let sig = git_commit_author(commit)
    else { return nil }
    
    return Signature(gitSignature: sig.pointee)
  }
  
  public var authorName: String?
  { authorSig?.name }
  
  public var authorEmail: String?
  { authorSig?.email }
  
  public var authorDate: Date?
  { authorSig?.when }
  
  public var committerSig: Signature?
  {
    guard let sig = git_commit_committer(commit)
    else { return nil }
    
    return Signature(gitSignature: sig.pointee)
  }
  
  public var committerName: String?
  { committerSig?.name }
  
  public var committerEmail: String?
  { committerSig?.email }
  
  public var commitDate: Date
  { committerSig?.when ?? Date() }
  
  public var email: String?
  { committerEmail }

  public var tree: Tree?
  {
    var tree: OpaquePointer?
    let result = git_commit_tree(&tree, commit)
    guard result == 0,
          let finalTree = tree
    else { return nil }
    
    return GitTree(tree: finalTree)
  }

  init?(gitCommit: OpaquePointer)
  {
    self.oid = GitOID(oidPtr: git_commit_id(gitCommit))
    self.commit = gitCommit
    self.parentOIDs = GitCommit.calculateParentOIDs(gitCommit)
  }

  convenience init?(oid: OID, repository: OpaquePointer)
  {
    guard let oid = oid as? GitOID
    else { return nil }
    var gitCommit: OpaquePointer?  // git_commit isn't imported
    let result = oid.withUnsafeOID {
      git_commit_lookup(&gitCommit, repository, $0)
    }
  
    guard result == 0,
          let finalCommit = gitCommit
    else { return nil }
    
    self.init(gitCommit: finalCommit)
  }
  
  convenience init?(sha: String, repository: OpaquePointer)
  {
    guard let oid = GitOID(sha: sha)
    else { return nil }
    
    self.init(oid: oid, repository: repository)
  }
  
  convenience init?(ref: String, repository: OpaquePointer)
  {
    var gitRefPtr: OpaquePointer? = nil
    guard git_reference_lookup(&gitRefPtr,
                               repository,
                               ref) == 0,
          let gitRef = gitRefPtr
    else { return nil }
    
    var gitObjectPtr: OpaquePointer? = nil
    guard git_reference_peel(&gitObjectPtr, gitRef, GIT_OBJECT_COMMIT) == 0,
          let gitObject = gitObjectPtr,
          git_object_type(gitObject) == GIT_OBJECT_COMMIT
    else { return nil }
    
    self.init(gitCommit: gitObject)
  }
  
  /// Returns a list of all files in the commit's tree, with paths relative
  /// to the root.
  func allFiles() -> [String]
  {
    guard let tree = tree as? GitTree
    else { return [] }
    
    var result = [String]()
    
    tree.walkEntries {
      (entry, root) in
      result.append(root.appending(pathComponent: entry.name))
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
}

public func == (a: GitCommit, b: GitCommit) -> Bool
{
  return (a.oid as! GitOID) == (b.oid as! GitOID)
}
