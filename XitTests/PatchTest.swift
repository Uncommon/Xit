import XCTest
@testable import Xit

class PatchTest: XCTestCase
{
  let testBundle = Bundle(identifier: "com.uncommonplace.XitTests")!
  var loremURL, lorem2URL: URL!
  var loremData, lorem2Data: Data!
  var loremText, lorem2Text: String!
  var delta: XTDiffDelta!
  var patch: GTDiffPatch!

  override func setUp()
  {
    loremURL = testBundle.url(forResource: "lorem",
                              withExtension: "txt")!
    lorem2URL = testBundle.url(forResource: "lorem2",
                               withExtension: "txt")!
    loremData = try! Data(contentsOf: loremURL)
    loremText = String(data: loremData, encoding: .utf8)!
    lorem2Data = try! Data(contentsOf: lorem2URL)
    lorem2Text = String(data: lorem2Data, encoding: .utf8)!
    delta = try! XTDiffDelta(from: loremData, forPath: nil,
                             to: lorem2Data, forPath: nil,
                             options: [GTDiffOptionsContextLinesKey:
                              PatchMaker.defaultContextLines])
    patch = try! delta.generatePatch()
  }

  func testApplyFirst()
  {
    let hunk1 = GTDiffHunk(patch: patch, hunkIndex: 0)!
    let applied = hunk1.applied(to: loremText, reversed: false)!
    
    XCTAssert(applied.hasPrefix(
        "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec nec maximus mauris. Quisque varius nisi ac augue rutrum ullamcorper. Sed tincidunt leo in erat commodo, tempor ultricies quam sagittis.\n" +
        "Duis risus quam, malesuada vel ante at, tincidunt sagittis erat. Phasellus a ante erat. Donec tristique lorem leo, sit amet congue est convallis vitae. Vestibulum a faucibus nisl. Pellentesque vitae sem vitae enim pharetra lacinia.\n" +
        "Pellentesque mattis ante eget dignissim cursus. Nullam lacinia sit amet sapien ac feugiat. Aenean sagittis eros dignissim volutpat faucibus. Proin laoreet tempus nunc in suscipit.\n\n"))
  }
  
  func testDiscardFirst()
  {
    let hunk1 = GTDiffHunk(patch: patch, hunkIndex: 0)!
    let applied = hunk1.applied(to: lorem2Text, reversed: true)!
    
    XCTAssert(applied.hasPrefix(
        "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec nec maximus mauris. Quisque varius nisi ac augue rutrum ullamcorper. Sed tincidunt leo in erat commodo, tempor ultricies quam sagittis.\n" +
        "Duis risus quam, malesuada vel ante at, tincidunt sagittis erat. Phasellus a ante erat. Donec tristique lorem leo, sit amet congue est convallis vitae. Vestibulum a faucibus nisl. Pellentesque vitae sem vitae enim pharetra lacinia.\n" +
        "Pellentesque mattis ante eget dignissim cursus. Nullam lacinia sit amet sapien ac feugiat. Aenean sagittis eros dignissim volutpat faucibus. Proin laoreet tempus nunc in suscipit.\n" +
        "Cras vestibulum id neque eu imperdiet. Pellentesque a lacus ipsum. Nulla ultrices consectetur congue.\n"))
  }
  
  func testApplyLast()
  {
    let hunk = GTDiffHunk(patch: patch, hunkIndex: patch.hunkCount-1)!
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
    let hunk = GTDiffHunk(patch: patch, hunkIndex: patch.hunkCount-1)!
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
    let hunk1 = GTDiffHunk(patch: patch, hunkIndex: 0)!
    
    XCTAssertNil(hunk1.applied(to: lorem2Text, reversed: false))
  }
}
