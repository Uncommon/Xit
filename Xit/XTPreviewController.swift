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
    (view as! QLPreviewView).previewItem = nil
    isLoaded = false
  }
  
  public func load(path: String!, model: XTFileChangesModel!, staged: Bool)
  {
    let previewView = view as! QLPreviewView
  
    if staged {
      var previewItem: PreviewItem! = previewView.previewItem
                                      as? PreviewItem
      
      if previewItem == nil {
        previewItem = PreviewItem()
        previewView.previewItem = previewItem
      }
      previewItem.model = model
      previewItem.path = path
      previewView.refreshPreviewItem()
      isLoaded = true
    }
    else {
      guard let urlString = model.unstagedFileURL(path)?.absoluteString
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
  }
}
