import Foundation

class GitBlame
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
    
    var blame: OpaquePointer? = nil
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
    let blame: GitBlame
    
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
    let blame: GitBlame
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

struct GitBlameHunk
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
