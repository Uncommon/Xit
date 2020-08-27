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
  func run(args: [String]) -> String
  {
    let data = try! runner.run(args: args)
    
    return String(data: data, encoding: .utf8)!.trimmingCharacters(in: .whitespacesAndNewlines)
  }
  
  func currentBranch() -> String
  {
    return run(args: ["rev-parse", "--abbrev-ref", "HEAD"])
  }
  
  /// Current branch will be prefixed by "* "
  func branches() -> [String]
  {
    return run(args: ["branch"]).components(separatedBy: .whitespacesAndNewlines)
  }
}
