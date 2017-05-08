import Foundation
import Quartz

// QLPreviewItem requires NSObjectProtocol, so it's best to just inherit
// from NSObject.
class PreviewItem: NSObject, QLPreviewItem
{
  var model: FileChangesModel!
  { didSet { remakeTempFile() } }
  var path: String?
  { didSet { remakeTempFile() } }
  var tempFolderPath: String?

  var previewItemURL: URL!
  
  override init()
  {
    let tempDir = NSTemporaryDirectory()
    let tempTemplate = tempDir.appending(pathComponent: "xtpreviewXXXXXX")
    
    tempFolderPath = tempTemplate.withCString {
      (template) -> String? in
      let mutableTemplate = UnsafeMutablePointer<Int8>(mutating: template)
      
      guard let dir = mkdtemp(mutableTemplate)
      else { return nil }
      
      return String(cString: dir)
    }
  }
  
  deinit
  {
    deleteTempFile()
    tempFolderPath?.withCString {
      (cPath) -> Void in
      rmdir(cPath)
    }
  }
  
  func tempFilePath() -> String?
  {
    guard let path = self.path
    else { return nil }
    
    return tempFolderPath?.appending(pathComponent:
        (path as NSString).lastPathComponent)
  }
  
  func deleteTempFile()
  {
    tempFilePath()?.withCString {
      (cPath) -> Void in
      unlink(cPath)
    }
  }
  
  func remakeTempFile()
  {
    deleteTempFile()
    previewItemURL = nil
    
    if let path = self.path,
       let model = self.model,
       let filePath = tempFilePath(),
       let contents = model.dataForFile(path, staged: true) {
      do {
        let url = URL(fileURLWithPath: filePath)
        
        try contents.write(to: url)
        previewItemURL = url
      }
      catch {}
    }
  }
}
