import Foundation
import AppKit

class RepoDocument: NSDocument
{
  private(set) var repository: XTRepository! = nil
  private(set) var repoURL: URL! = nil

  enum Error: Swift.Error
  {
    case notAllowed
    case failed
  }

  // Don't allow creating an untitled document
  convenience init(type typeName: String) throws
  {
    throw NSError(osStatus: -1)
  }

  override func makeWindowControllers()
  {
    let storyboard = NSStoryboard(name: "XTDocument", bundle: nil)

    if let controller = storyboard.instantiateInitialController()
        as? XTWindowController {
      addWindowController(controller)
      controller.finalizeSetup()
    }
  }

  override func read(from url: URL, ofType typeName: String) throws
  {
    let gitURL = url.appendingPathComponent(".git")

    if !FileManager.default.fileExists(atPath: gitURL.path) {
      throw NSError(domain: NSCocoaErrorDomain,
                    code: NSFileReadUnknownError,
                    userInfo: [NSLocalizedFailureReasonErrorKey:
                               "The folder does not contain a Git repository."])
    }

    guard let repository = XTRepository(url: url)
    else {
      throw NSError(domain: NSCocoaErrorDomain,
                    code: NSFileReadNoSuchFileError)
    }

    self.repoURL = url
    self.repository = repository

    (NSApp.delegate as? AppDelegate)?.dismissOpenPanel()
  }

  override func canClose(withDelegate delegate: Any,
                         shouldClose shouldCloseSelector: Selector?,
                         contextInfo: UnsafeMutableRawPointer?)
  {
    if let controller = windowControllers.first as? XTWindowController {
      controller.shutDown()
    }

    super.canClose(withDelegate: delegate,
                   shouldClose: shouldCloseSelector,
                   contextInfo: contextInfo)
  }

  override func updateChangeCount(_ change: NSDocument.ChangeType)
  {
    // Do nothing. There is no need for an "unsaved" state.
  }
}
