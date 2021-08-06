import Foundation
import XCTest

enum TestRepo: String
{
  case conflicted = "conflicted-repo"
  case submodule = "repo-with-submodule"
  case testApp = "Test_App"
  case testAppFork = "Test_App_fork"
  case unicode = "unicode-files-repo"
  
  var defaultBranches: [String]
  {
    switch self {
      case .testApp:
        return [
            "1-and_more", "and-how", "andhow-ad", "asdf", "blah", "feature",
            "hi!", "master", "new", "other-branch", "wat", "whateelse", "whup",
            ]
      case .unicode:
        return ["master"]
      default:
        return []
    }
  }
  
  func extract(to targetPath: String) -> Bool
  {
    return XCTContext.runActivity(named: "Extract test repo \(rawValue)") { _ in
      let bundle = Bundle(identifier: "com.uncommonplace.XitUITests")!
      let fixturesURL = bundle.url(forResource: "fixtures",
                                   withExtension: "zip")!
      let unzipTask = Process()

      try? FileManager.default.removeItem(atPath:
          targetPath.appending(pathComponent: rawValue))
      unzipTask.launchPath = "/usr/bin/unzip"
      unzipTask.arguments = ["-uo", fixturesURL.path, rawValue + "/*"]
      unzipTask.currentDirectoryPath = targetPath

      NSLog("unzipping \(rawValue) to \(targetPath)")
      unzipTask.launch()
      unzipTask.waitUntilExit()

      guard unzipTask.terminationStatus == 0
      else {
        XCTFail("unzip failed")
        return false
      }
      return true
    }
  }
}
