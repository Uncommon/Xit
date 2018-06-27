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
  
  public func load(path: String!, fileList: FileListModel)
  {
    let previewView = qlView
  
    if fileList is WorkspaceFileList {
      guard let urlString = fileList.fileURL(path)?.absoluteString
      else {
        previewView.previewItem = nil
        isLoaded = true
        return
      }
      // Swift's URL doesn't conform to QLPreviewItem because it's not a class
      let nsurl = NSURL(string: urlString)
    
      DispatchQueue.main.async {
        previewView.previewItem = nsurl
        self.isLoaded = true
      }
    }
    else {
      var previewItem: PreviewItem! = previewView.previewItem
        as? PreviewItem
      
      DispatchQueue.main.async {
        if previewItem == nil {
          previewItem = PreviewItem()
          previewView.previewItem = previewItem
        }
        previewItem.fileList = fileList
        previewItem.path = path
        previewView.refreshPreviewItem()
        self.isLoaded = true
      }
    }
  }
}
