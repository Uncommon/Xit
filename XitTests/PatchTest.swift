import XCTest
@testable import Xit

class PatchTest: XCTestCase
{
  let testBundle = Bundle(identifier: "com.uncommonplace.XitTests")!
  var loremURL, lorem2URL: URL!
  var loremData, lorem2Data: Data!
  var loremText, lorem2Text: String!
  var patch: (any Patch)!

  override func setUpWithError() throws
  {
    try super.setUpWithError()

    loremURL = testBundle.url(forResource: "lorem",
                              withExtension: "txt")!
    lorem2URL = testBundle.url(forResource: "lorem2",
                               withExtension: "txt")!
    loremData = try Data(contentsOf: loremURL)
    loremText = try XCTUnwrap(String(data: loremData, encoding: .utf8))
    lorem2Data = try Data(contentsOf: lorem2URL)
    lorem2Text = try XCTUnwrap(String(data: lorem2Data, encoding: .utf8))
    patch = GitPatch(oldData: loremData, newData: lorem2Data)
  }

  func testApplyFirst()
  {
    guard let hunk1 = patch.hunk(at: 0)
    else {
      XCTFail("no hunk")
      return
    }
    let applied = hunk1.applied(to: loremText, reversed: false)!
    
    XCTAssert(applied.hasPrefix(
        "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec nec maximus mauris. Quisque varius nisi ac augue rutrum ullamcorper. Sed tincidunt leo in erat commodo, tempor ultricies quam sagittis.\n" +
        "Duis risus quam, malesuada vel ante at, tincidunt sagittis erat. Phasellus a ante erat. Donec tristique lorem leo, sit amet congue est convallis vitae. Vestibulum a faucibus nisl. Pellentesque vitae sem vitae enim pharetra lacinia.\n" +
        "Pellentesque mattis ante eget dignissim cursus. Nullam lacinia sit amet sapien ac feugiat. Aenean sagittis eros dignissim volutpat faucibus. Proin laoreet tempus nunc in suscipit.\n\n"))
  }
  
  func testDiscardFirst()
  {
    guard let hunk1 = patch.hunk(at: 0)
    else {
      XCTFail("no hunk")
      return
    }
    let applied = hunk1.applied(to: lorem2Text, reversed: true)!
    
    XCTAssert(applied.hasPrefix(
        "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec nec maximus mauris. Quisque varius nisi ac augue rutrum ullamcorper. Sed tincidunt leo in erat commodo, tempor ultricies quam sagittis.\n" +
        "Duis risus quam, malesuada vel ante at, tincidunt sagittis erat. Phasellus a ante erat. Donec tristique lorem leo, sit amet congue est convallis vitae. Vestibulum a faucibus nisl. Pellentesque vitae sem vitae enim pharetra lacinia.\n" +
        "Pellentesque mattis ante eget dignissim cursus. Nullam lacinia sit amet sapien ac feugiat. Aenean sagittis eros dignissim volutpat faucibus. Proin laoreet tempus nunc in suscipit.\n" +
        "Cras vestibulum id neque eu imperdiet. Pellentesque a lacus ipsum. Nulla ultrices consectetur congue.\n"))
  }
  
  func testApplyLast()
  {
    guard let hunk = patch.hunk(at: patch.hunkCount-1)
    else {
      XCTFail("no hunk")
      return
    }
    let applied = hunk.applied(to: loremText, reversed: false)!
    
    XCTAssert(applied.hasSuffix(
        "Cras et rutrum dolor awk.\n" +
        "Thistledown.\n" +
        "Proin sit amet justo egestas, pulvinar mauris sit amet, ultrices tellus.\n" +
        "Ut molestie elit justo, at pellentesque metus lacinia eu. Duis vitae hendrerit justo. Nam porta in augue viverra blandit.\n" +
        "Phasellus id aliquam quam, gravida volutpat nunc. Aliquam at ligula sem. Mauris in luctus ante, sit amet lacinia nunc.\n" +
        "Maecenas dictum, ipsum vitae iaculis dignissim, nulla ligula rhoncus tortor, eget rutrum velit lacus fringilla dui. Nulla facilisis urna eu facilisis ornare.\n" +
        "Mauris iaculis metus nibh, et dapibus ante ultricies quis.\n"))
  }
  
  func testDiscardLast()
  {
    guard let hunk = patch.hunk(at: patch.hunkCount-1)
    else {
      XCTFail("no hunk")
      return
    }
    let applied = hunk.applied(to: lorem2Text, reversed: true)!
    
    XCTAssert(applied.hasSuffix(
        "Cras et rutrum dolor.\n" +
        "Proin sit amet justo egestas, pulvinar mauris sit amet, ultrices tellus.\n" +
        "Ut molestie elit justo, at pellentesque metus lacinia eu. Duis vitae hendrerit justo. Nam porta in augue viverra blandit.\n" +
        "Phasellus id aliquam quam, gravida volutpat nunc. Aliquam at ligula sem. Mauris in luctus ante, sit amet lacinia nunc.\n" +
        "Maecenas dictum, ipsum vitae iaculis dignissim, nulla ligula rhoncus tortor, eget rutrum velit lacus fringilla dui. Nulla facilisis urna eu facilisis ornare.\n" +
        "Mauris iaculis metus nibh, et dapibus ante ultricies quis.\n"))
  }
  
  func testNotApplied()
  {
    let lorem2Text = String(data: lorem2Data, encoding: .utf8)!
    guard let hunk1 = patch.hunk(at: 0)
    else {
      XCTFail("no hunk")
      return
    }
    
    XCTAssertNil(hunk1.applied(to: lorem2Text, reversed: false))
  }
}
