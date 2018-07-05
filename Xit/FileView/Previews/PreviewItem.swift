import Foundation
import Quartz

// QLPreviewItem requires NSObjectProtocol, so it's best to just inherit
// from NSObject.
class PreviewItem: NSObject
{
  var fileList: FileListModel!
  var path: String?
  var tempFolderPath: String?

  let urlLock = Mutex()
  var url = URL(string: "")
  
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
  
  func load(fileList: FileListModel, path: String)
  {
    self.fileList = fileList
    self.path = path
    remakeTempFile()
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
       let filePath = tempFilePath(),
       let contents = fileList?.dataForFile(path) {
      do {
        let url = URL(fileURLWithPath: filePath)
        
        try contents.write(to: url)
        previewItemURL = url
      }
      catch {
        previewItemURL = URL(string: "")
      }
    }
  }
}

extension PreviewItem: QLPreviewItem
{
  var previewItemURL: URL!
  {
    get { return urlLock.withLock { return url } }
    set { urlLock.withLock { url = newValue } }
  }
}
