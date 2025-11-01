import Foundation

class GitCLI
{
  let runner: CLIRunner
  
  init(repoURL: URL)
  {
    let gitURL = Bundle(identifier: "com.uncommonplace.XitUITests")!
                 .url(forAuxiliaryExecutable: "git")!
    
    self.runner = CLIRunner(toolPath: gitURL.path, workingDir: repoURL.path)
  }
  
  @discardableResult
  func run(args: [String]) throws -> String
  {
    let data = try runner.run(args: args)
    
    return String(data: data, encoding: .utf8)!.trimmingCharacters(in: .whitespacesAndNewlines)
  }
  
  func currentBranch() throws -> String
  {
    try run(args: ["rev-parse", "--abbrev-ref", "HEAD"])
  }
  
  /// Current branch will be prefixed by "* "
  func branches() throws -> [String]
  {
    try run(args: ["branch"]).components(separatedBy: .whitespacesAndNewlines)
  }

  func tags() throws -> [String]
  {
    try run(args: ["tag", "-l"]).components(separatedBy: .whitespacesAndNewlines)
  }

  func checkOut(branch: String) throws
  {
    try run(args: ["checkout", branch])
  }
  
  func checkOut(newBranch: String) throws
  {
    try run(args: ["checkout", "-b", newBranch])
  }
}
