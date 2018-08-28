import Foundation
import Quartz

/// Controller for the QuickLook preview tab.
class XTPreviewController: NSViewController
{
  var isLoaded: Bool = false
  
  var qlView: QLPreviewView { return view as! QLPreviewView }
  
  override func awakeFromNib()
  {
    // Having the QL view in the xib was causing odd problems
    view = QLPreviewView(frame: NSRect(x: 0, y: 0, width: 50, height: 50),
                         style: .normal)
  }
  
  func refreshPreviewItem()
  {
    qlView.refreshPreviewItem()
  }
}

extension XTPreviewController: XTFileContentController
{
  public func clear()
  {
    qlView.previewItem = nil
    isLoaded = false
  }
  
  public func load(path: String!, selection: RepositorySelection,
                   fileList: FileListModel)
  {
    let qlView = self.qlView
  
    if fileList is WorkspaceFileList {
      guard let urlString = fileList.fileURL(path)?.absoluteString
      else {
        qlView.previewItem = nil
        isLoaded = true
        return
      }
      // Swift's URL doesn't conform to QLPreviewItem because it's not a class
      let nsurl = NSURL(string: urlString)
      guard qlView.previewItem as? NSURL != nsurl
      else {
        return
      }
    
      DispatchQueue.main.async {
        qlView.previewItem = nsurl
        self.isLoaded = true
      }
    }
    else {
      if let oldItem = qlView.previewItem as? PreviewItem,
         oldItem.path == path && oldItem.fileList == fileList {
        return
      }
      
      DispatchQueue.main.async {
        let item = PreviewItem()
        
        item.load(fileList: fileList, path: path)
        qlView.previewItem = item
        self.isLoaded = true
      }
    }
  }
}
