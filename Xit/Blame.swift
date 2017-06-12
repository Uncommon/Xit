import Foundation

protocol Blame
{
  associatedtype HunkCollection: Collection
  
  var hunks: HunkCollection! { get }
}

protocol BlameHunk
{
  associatedtype ID: OID
  
  var lineCount: Int { get }
  var boundary: Bool { get }
  
  var finalOID: ID { get } // OIDs are zero for local changes
  var finalLineStart: Int { get }
  var finalSignature: Signature { get }
  
  var origOID: ID { get }
  var origLineStart: Int { get }
  var origSignature: Signature { get }
}

class Git2Blame: Blame
{
  let blame: OpaquePointer
  public private(set) var hunks: HunkCollection!
  
  var hunkCount: UInt
  { return UInt(git_blame_get_hunk_count(blame)) }
  
  init?(repository: XTRepository, path: String,
        from startOID: GitOID?, to endOID: GitOID?)
  {
    let options = UnsafeMutablePointer<git_blame_options>.allocate(capacity: 1)
    
    git_blame_init_options(options, 1)
    if let startOID = startOID {
      options.pointee.newest_commit = startOID.oid
    }
    if let endOID = endOID {
      options.pointee.oldest_commit = endOID.oid
    }
    
    var blame: OpaquePointer?
    let result = git_blame_file(&blame, repository.gtRepo.git_repository(),
                                path, options)
    
    guard result == GIT_OK.rawValue,
          blame != nil
    else { return nil }
    
    self.blame = blame!
    self.hunks = HunkCollection(blame: self)
  }
  
  deinit
  {
    git_blame_free(blame)
  }
  
  struct HunkCollection: Collection
  {
    let blame: Git2Blame
    
    func makeIterator() -> HunkIterator
    {
      return HunkIterator(blame: blame, index: 0)
    }
    
    subscript(position: Int) -> GitBlameHunk
    {
      return blame.hunk(atIndex: UInt(position))!
    }
    
    var startIndex: Int { return 0 }
    var endIndex: Int { return Int(blame.hunkCount) }
    
    func index(after i: Int) -> Int
    {
      return i + 1
    }
    func index(before i: Int) -> Int
    {
      return i - 1
    }
  }
  
  struct HunkIterator: IteratorProtocol
  {
    let blame: Git2Blame
    var index: UInt
    
    mutating func next() -> GitBlameHunk?
    {
      return blame.hunk(atIndex: index++)
    }
  }
  
  func hunk(atIndex index: UInt) -> GitBlameHunk?
  {
    guard let result = git_blame_get_hunk_byindex(blame, UInt32(index))
    else { return nil }
    
    return GitBlameHunk(
      hunk: UnsafeMutablePointer<git_blame_hunk>(mutating: result).move())
  }
  
  func hunk(atLine line: UInt) -> GitBlameHunk?
  {
    guard let result = git_blame_get_hunk_byline(blame, Int(line))
    else { return nil }
    
    return GitBlameHunk(
        hunk: UnsafeMutablePointer<git_blame_hunk>(mutating: result).move())
  }
}

struct GitBlameHunk: BlameHunk
{
  let hunk: git_blame_hunk
  
  var lineCount: Int { return hunk.lines_in_hunk }
  var boundary: Bool { return hunk.boundary == 1 }
  
  var finalOID: GitOID { return GitOID(oid: hunk.final_commit_id) }
  var finalLineStart: Int { return hunk.final_start_line_number }
  var finalSignature: Signature
  { return GitSignature(signature: hunk.final_signature.pointee) }
  
  var origOID: GitOID { return GitOID(oid: hunk.orig_commit_id) }
  var origLineStart: Int { return hunk.orig_start_line_number }
  var origSignature: Signature
  { return GitSignature(signature: hunk.orig_signature.pointee) }
}

/// Blame data from the git command line because libgit2 is slow
class CLGitBlame: Blame
{
  typealias HunkCollection = [CLGitBlameHunk]
  
  var hunks: [CLGitBlameHunk]! = [CLGitBlameHunk]()
  
  func read(data: Data, from repository: XTRepository) -> Bool
  {
    guard let text = String(data: data, encoding: .utf8)
    else { return false }
    
    let lines = text.components(separatedBy: .newlines)
    var startHunk = true
    
    for line in lines {
      if startHunk {
        let parts = line.components(separatedBy: .whitespaces)
        guard parts.count >= 3,
              let oid = GitOID(sha: parts[0])
        else { continue }
        
        if let last = hunks.last,
          oid == last.origOID {
          last.lineCount += 1
        }
        else {
          guard let originalLine = Int(parts[1]),
                let finalLine = Int(parts[2])
            else { continue }
          
          var authorSig, committerSig: Signature!
          
          if oid.isZero {
            authorSig = GitSignature(signature:
                repository.gtRepo.userSignatureForNow().git_signature().pointee)
            committerSig = authorSig
          }
          else {
            guard let commit = repository.commit(forOID: oid)
            else { continue }
            
            authorSig = commit.authorSig
            committerSig = commit.committerSig
          }
          
          // The output doesn't have the original commit SHA so fake it
          // by using author/committer
          let hunk = CLGitBlameHunk(lineCount: 1, boundary: false,
                                    finalOID: oid,
                                    finalLineStart: finalLine,
                                    finalSignature: committerSig,
                                    origOID: oid,
                                    origLineStart: originalLine,
                                    origSignature: authorSig)
          
          hunks.append(hunk)
        }
        startHunk = false
      }
      else if line.hasPrefix("\t") {
        // This line has the text from the file after the tab
        // but we're not collecting that here.
        startHunk = true
      }
      // Other lines that don't start with a tab have author & committer
      // info, but we're getting that from the commit.
    }
    return true
  }
  
  init?(repository: XTRepository, path: String,
        from startOID: GitOID?, to endOID: GitOID?)
  {
    var args = ["blame", "-p", path]
    
    if let sha = startOID?.sha {
      args.insert(contentsOf: [sha, "--"], at: 2)
    }
    
    guard let data = try? repository.executeGit(args: args, writes: false),
          read(data: data, from: repository)
    else { return nil }
  }
  
  init?(repository: XTRepository, path: String,
        data: Data, to endOID: GitOID?)
  {
    let args = ["blame", "-p", "--contents", "-", path]
    
    guard let input = String(data: data, encoding: .utf8),
          let data = try? repository.executeGit(args: args,
                                                stdIn: input,
                                                writes: false),
          read(data: data, from: repository)
    else { return nil }
  }
}

class CLGitBlameHunk: BlameHunk
{
  var lineCount: Int
  var boundary: Bool
  
  var finalOID: GitOID
  var finalLineStart: Int
  var finalSignature: Signature
  
  var origOID: GitOID
  var origLineStart: Int
  var origSignature: Signature
  
  init(lineCount: Int, boundary: Bool, finalOID: GitOID, finalLineStart: Int,
       finalSignature: Signature, origOID: GitOID, origLineStart: Int,
       origSignature: Signature)
  {
    self.lineCount = lineCount
    self.boundary = boundary
    self.finalOID = finalOID
    self.finalLineStart = finalLineStart
    self.finalSignature = finalSignature
    self.origOID = origOID
    self.origLineStart = origLineStart
    self.origSignature = origSignature
  }
}
