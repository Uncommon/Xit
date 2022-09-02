import XCTest
@testable import Xit

class RepoDocumentTest: XTTest
{
  func testOpenClose() throws
  {
    measure(metrics: [XCTMemoryMetric()]) {
      let controller = XTDocumentController.shared
      let document = try? controller.makeDocument(withContentsOf:repository.repoURL,
                                                  ofType: "folder")

      XCTAssertNotNil(document)
      document!.makeWindowControllers()
      document!.windowControllers.first!.showWindow(nil)
      //XCTAssertEqual(controller.documents.count, 1)
      document?.close()
    }
  }
}
