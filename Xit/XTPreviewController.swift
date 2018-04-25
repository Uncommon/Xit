import Foundation
import Quartz

/// Controller for the QuickLook preview tab.
class XTPreviewController: NSViewController
{
  var isLoaded: Bool = false
}

extension XTPreviewController: XTFileContentController
{
  public func clear()
  {
    //(view as! QLPreviewView).previewItem = nil
    isLoaded = false
  }
  
  public func load(path: String!, fileList: FileListModel)
  {
    return // TODO: fix preview
    let previewView = view as! QLPreviewView
  
    if fileList is WorkspaceFileList {
      guard let urlString = fileList.fileURL(path)?.absoluteString
      else {
        previewView.previewItem = nil
        isLoaded = true
        return
      }
      // Swift's URL doesn't conform to QLPreviewItem because it's not a class
      let nsurl = NSURL(string: urlString)
    
      previewView.previewItem = nsurl
      isLoaded = true
    }
    else {
      var previewItem: PreviewItem! = previewView.previewItem
        as? PreviewItem
      
      if previewItem == nil {
        previewItem = PreviewItem()
        previewView.previewItem = previewItem
      }
      previewItem.fileList = fileList
      previewItem.path = path
      previewView.refreshPreviewItem()
      isLoaded = true
    }
  }
}
