import Cocoa

class PrefsTabViewController: NSTabViewController
{
  @IBOutlet weak var previewsTab: NSTabViewItem!
  
  override func viewDidLoad()
  {
    super.viewDidLoad()
    
    // The generic document icon isn't available in Interface Builder.
    previewsTab.image = NSWorkspace.shared().icon(forFileType:
        NSFileTypeForHFSTypeCode(OSType(kGenericDocumentIcon)))
  }
}
