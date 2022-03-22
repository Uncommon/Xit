import Foundation

public protocol Blame
{
  var hunks: [BlameHunk] { get }
}

public class BlameHunk
{
  struct LineInfo
  {
    let oid: any OID // OIDs are zero for local changes
    let start: Int
    let signature: Signature
  }
  
  fileprivate(set) var lineCount: Int
  let boundary: Bool
  
  let originalLine: LineInfo
  let finalLine: LineInfo
  
  init(lineCount: Int, boundary: Bool,
       originalLine: LineInfo, finalLine: LineInfo)
  {
    self.lineCount = lineCount
    self.boundary = boundary
    self.originalLine = originalLine
    self.finalLine = finalLine
  }
}

/// Blame data from the git command line because libgit2 is slow
public final class GitBlame: Blame
{
  public var hunks = [BlameHunk]()
  
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
           oid == (last.originalLine.oid as? GitOID) {
          last.lineCount += 1
        }
        else {
          guard let originalLine = Int(parts[1]),
                let finalLine = Int(parts[2])
          else { continue }
          
          var authorSig, committerSig: Signature!
          
          if oid.isZero {
            authorSig = Signature(defaultFromRepo: repository.gitRepo)
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
          let hunk = BlameHunk(lineCount: 1, boundary: false,
                               originalLine: BlameHunk.LineInfo(
                                    oid: oid, start: originalLine,
                                    signature: authorSig),
                               finalLine: BlameHunk.LineInfo(
                                    oid: oid, start: finalLine,
                                    signature: committerSig))
          
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
        from startOID: (any OID)?, to endOID: (any OID)?)
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
        data: Data, to endOID: (any OID)?)
  {
    let args = ["blame", "-p", "--contents", "-", path]
    
    guard let data = try? repository.executeGit(args: args,
                                                stdInData: data,
                                                writes: false),
          read(data: data, from: repository)
    else { return nil }
  }
}
