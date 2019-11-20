import AppKit

/// Shared code for setting up, opening, and operating on a test repository.
class TestRepoEnvironment
{
  let repo: TestRepo
  let tempDir = TemporaryDirectory("XitTest")
  let git: GitCLI
  let repoURL: URL
  
  init?(_ repo: TestRepo)
  {
    guard let tempURL = tempDir?.url,
          repo.extract(to: tempURL.path)
    else { return nil }
    
    self.repo = repo
    self.repoURL = tempURL.appendingPathComponent(repo.rawValue)
    self.git = GitCLI(repoURL: repoURL)
  }
  
  func open()
  {
    XitApp.launchArguments = ["-noServices", "YES"]
    XitApp.launch()
    XitApp.activate()
    
    NSWorkspace.shared.openFile(repoURL.path, withApplication: "Xit")
  }
}
