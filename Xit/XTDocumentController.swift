import Cocoa

final class XTDocumentController: NSDocumentController
{
  // This can get triggered by clicking the new tab button in a tabbed window.
  override func newDocument(_ sender: Any?)
  {
    _ = NSApp.delegate?.perform(#selector(openDocument(_:)), with: sender)
  }


  override func openUntitledDocumentAndDisplay(_ displayDocument: Bool) throws
    -> NSDocument
  {
    throw NSError(domain: NSCocoaErrorDomain,
                  code: CocoaError.featureUnsupported.rawValue)
  }

  override func makeUntitledDocument(ofType typeName: String) throws
    -> NSDocument {
    throw NSError(domain: NSCocoaErrorDomain,
                  code: CocoaError.featureUnsupported.rawValue)
  }

  override func makeDocument(withContentsOf url: URL,
                             ofType typeName: String) throws -> NSDocument
  {
    try RepoDocument(contentsOf: url, ofType: typeName)
  }

  override func makeDocument(for urlOrNil: URL?,
                             withContentsOf contentsURL: URL,
                             ofType typeName: String) throws -> NSDocument
  {
    try RepoDocument(contentsOf: contentsURL, ofType: typeName)
  }
}
