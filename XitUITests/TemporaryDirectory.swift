import Foundation

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
                                  attributes: nil)
    }
    catch {
      return nil
    }
  }
  
  deinit
  {
    try? FileManager.default.removeItem(at: url)
  }
}
