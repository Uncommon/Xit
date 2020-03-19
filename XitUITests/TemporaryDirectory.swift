import Foundation
import XCTest

class TemporaryDirectory
{
  let url: URL
  
  init?(_ name: String, clearFirst: Bool = true)
  {
    let manager = FileManager.default
    
    self.url = manager.temporaryDirectory
                      .appendingPathComponent(name, isDirectory: true)
    do {
      if clearFirst && manager.fileExists(atPath: url.path) {
        try manager.removeItem(at: url)
      }
      try manager.createDirectory(at: url,
                                  withIntermediateDirectories: true,
                                  attributes: [.posixPermissions:0o777])
    }
    catch let error as NSError {
      XCTFail("Temp directory failed: \(error.description)")
      return nil
    }
    catch {
      return nil
    }
  }
  
  deinit
  {
    do {
      try FileManager.default.removeItem(at: url)
    }
    catch let error as NSError {
      print("failed to delete temp dir: \(error.description)")
    }
  }
}
