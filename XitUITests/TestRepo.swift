import Foundation
import XCTest

enum TestRepo: String
{
  case conflicted = "conflicted-repo"
  case submodule = "repo-with-submodule"
  case testApp = "Test_App"
  case testAppFork = "Test_App_fork"
  case unicode = "unicode-files-repo"
  
  func extract(to targetPath: String) -> Bool
  {
    let bundle = Bundle(identifier: "com.uncommonplace.XitUITests")!
    let fixturesURL = bundle.url(forResource: "fixtures",
                                 withExtension: "zip")!
    let unzipTask = Process()
    
    unzipTask.launchPath = "/usr/bin/unzip"
    unzipTask.arguments = [fixturesURL.path, rawValue + "/*"]
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
