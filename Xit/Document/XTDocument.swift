import Foundation

class XTDocument: NSDocument
{
  private(set) var repoURL: URL!
  private(set) var repository: XTRepository!
  
  override func makeWindowControllers()
  {
    let storyboard = NSStoryboard(name: "XTDocument", bundle: nil)
    let controller = storyboard.instantiateInitialController()
                     as! XTWindowController
    
    addWindowController(controller)
  }
  
  override func read(from url: URL, ofType typeName: String) throws
  {
    let gitURL = url.appendingPathComponent(".git")
    
    guard FileManager.default.fileExists(atPath: gitURL.path)
    else {
      throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadUnknownError,
                    userInfo: [NSLocalizedFailureReasonErrorKey:
                               "The folder does not contain a Git repository."])
    }
    guard let repository = XTRepository(url: url)
    else {
      throw NSError(domain: "xit", code: -1,
                    userInfo: [NSLocalizedDescriptionKey:
                               "The repository could not be opened"])
    }

    self.repoURL = url
    self.repository = repository
    
    (NSApp.delegate as! AppDelegate).dismissOpenPanel()
  }
  
  override func canClose(withDelegate delegate: Any,
                         shouldClose shouldCloseSelector: Selector?,
                         contextInfo: UnsafeMutableRawPointer?)
  {
    let controller = windowControllers.first as! XTWindowController
    
    controller.shutDown()
    
    super.canClose(withDelegate: delegate,
                   shouldClose: shouldCloseSelector,
                   contextInfo: contextInfo)
  }
  
  override func updateChangeCount(_ change: NSDocument.ChangeType)
  {
    // Do nothing. There is no need for an "unsaved" state.
  }
}
