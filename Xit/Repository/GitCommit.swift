import Cocoa


public protocol Commit<ObjectIdentifier>: OIDObject, CustomStringConvertible
{
  associatedtype ObjectIdentifier
  associatedtype Tree: Xit.Tree<ObjectIdentifier>

  // Strictly speaking these should probably all be the same OID type
  var parentOIDs: [ObjectIdentifier] { get }
  
  var message: String? { get }
  
  var authorSig: Signature? { get }
  var committerSig: Signature? { get }
  
  var authorName: String? { get }
  var authorEmail: String? { get }
  var authorDate: Date? { get }
  var committerName: String? { get }
  var committerEmail: String? { get }
  var commitDate: Date { get }
  
  var tree: Tree? { get }

  var isSigned: Bool { get }

  func getTrailers() -> [(String, [String])]
}

extension Commit
{
  /// Because `tree` is a "generic" associated type the compiler wants an
  /// explicit conversion to the unconstrained existential.
  var anyTree: (any Xit.Tree)?
  {
    tree as (any Xit.Tree)?
  }
}

extension Commit
{
  var authorName: String? { authorSig?.name }
  var authorEmail: String? { authorSig?.email }
  var authorDate: Date? { authorSig?.when }
  var committerName: String? { committerSig?.name }
  var committerEmail: String? { committerSig?.email }
  var commitDate: Date { committerSig?.when ?? Date() }
  
  var email: String? { committerEmail }
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
  { id.sha.firstSix() }
}

public final class GitCommit: Commit
{
  public typealias ObjectIdentifier = GitOID
  public typealias Tree = GitTree

  let commit: OpaquePointer

  public let id: GitOID
  public let parentOIDs: [GitOID]
  
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

  public var tree: GitTree?
  {
    guard let tree = try? OpaquePointer.from({
      git_commit_tree(&$0, commit)
    })
    else { return nil }
    
    return GitTree(tree: tree)
  }

  public var isSigned: Bool
  {
    // Immitate git_commit_extract_signature() but just check that it exists
    guard let odb = GitODB(repository: repository),
          let object = odb[id]
    else { return false }
    let text = object.text

    return text.lines.contains {
      $0.hasPrefix("gpgsig")
    }
  }

  init?(gitCommit: OpaquePointer)
  {
    self.id = GitOID(oidPtr: git_commit_id(gitCommit))
    self.commit = gitCommit
    self.parentOIDs = GitCommit.calculateParentOIDs(gitCommit)
  }

  convenience init?(oid: any OID, repository: OpaquePointer)
  {
    guard let oid = oid as? GitOID,
          let commit = try? OpaquePointer.from({
            (commit) in
            oid.withUnsafeOID { git_commit_lookup(&commit, repository, $0) }
          })
    else { return nil }
    
    self.init(gitCommit: commit)
  }
  
  convenience init?(sha: String, repository: OpaquePointer)
  {
    guard let oid = GitOID(sha: sha)
    else { return nil }
    
    self.init(oid: oid, repository: repository)
  }
  
  convenience init?(ref: String, repository: OpaquePointer)
  {
    guard let gitRef = try? OpaquePointer.from({
            git_reference_lookup(&$0, repository, ref)
          }),
          let gitObject = try? OpaquePointer.from({
            git_reference_peel(&$0, gitRef, GIT_OBJECT_COMMIT)
          }),
          git_object_type(gitObject) == GIT_OBJECT_COMMIT
    else { return nil }
    
    self.init(gitCommit: gitObject)
  }

  public func getTrailers() -> [(String, [String])]
  {
    guard let message = self.message
    else { return [] }
    var trailers = git_message_trailer_array()
    guard git_message_trailers(&trailers, message) == 0
    else { return [] }
    defer {
      git_message_trailer_array_free(&trailers)
    }

    var result: [(String, [String])] = []

    for i in 0..<trailers.count {
      let key: String = .init(cString: trailers.trailers[i].key)
      let value: String = .init(cString: trailers.trailers[i].value)

      if let index = result.firstIndex(where: { $0.0 == key }) {
        result[index].1.append(value)
      }
      else {
        result.append((key, [value]))
      }
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
