import Foundation

protocol RefLog
{
  var entryCount: Int { get }
  
  func entry(atIndex index: Int) -> RefLogEntry
  func dropEntry(atIndex index: Int, rewrite: Bool) throws
  
  func write() throws
  func append(oid: OID, committer: Signature, message: String) throws
}

extension RefLog
{
  var entries: RefLogEntryCollection
  { RefLogEntryCollection(refLog: self) }
}

protocol RefLogEntry
{
  var oldOID: OID { get }
  var newOID: OID { get }
  var committer: Signature { get }
  var message: String { get }
}

struct RefLogEntryCollection: RandomAccessCollection
{
  let refLog: RefLog
  
  var startIndex: Int { 0 }
  var endIndex: Int { refLog.entryCount }
  
  subscript(position: Int) -> RefLogEntry
  {
    return refLog.entry(atIndex: position)
  }
}


struct GitRefLogEntry: RefLogEntry
{
  let entry: OpaquePointer
  
  var oldOID: OID { GitOID(oidPtr: git_reflog_entry_id_old(entry)) }
  var newOID: OID { GitOID(oidPtr: git_reflog_entry_id_new(entry)) }
  var committer: Signature
  {
    if let committer = git_reflog_entry_committer(entry) {
      return Signature(gitSignature: committer.pointee)
    }
    else {
      return Signature(name: nil, email: nil, when: Date())
    }
  }
  var message: String { .init(cString: git_reflog_entry_message(entry)) }
}

final class GitRefLog
{
  let refLog: OpaquePointer
  
  init?(repository: OpaquePointer, refName: String)
  {
    guard let refLog = try? OpaquePointer.from({
      git_reflog_read(&$0, repository, refName)
    })
    else { return nil }
    
    self.refLog = refLog
  }
  
  deinit
  {
    git_reflog_free(refLog)
  }
}

extension GitRefLog: RefLog
{
  var entryCount: Int { git_reflog_entrycount(refLog) }
  
  func entry(atIndex index: Int) -> RefLogEntry
  {
    let entry = git_reflog_entry_byindex(refLog, index)!
    
    return GitRefLogEntry(entry: entry)
  }
  
  func dropEntry(atIndex index: Int, rewrite: Bool) throws
  {
    let result = git_reflog_drop(refLog, index, rewrite ? 1 : 0)
    
    try RepoError.throwIfGitError(result)
  }
  
  func write() throws
  {
    try RepoError.throwIfGitError(git_reflog_write(refLog))
  }
  
  func append(oid: OID, committer: Signature, message: String) throws
  {
    guard var gitOID = (oid as? GitOID)?.oid
    else {
      throw RepoError.unexpected
    }
    
    let result = committer.withGitSignature {
      (signature) -> Int32 in
      var mutableSignature = signature
      
      return git_reflog_append(refLog, &gitOID, &mutableSignature, message)
    }
    
    try RepoError.throwIfGitError(result)
  }
}
