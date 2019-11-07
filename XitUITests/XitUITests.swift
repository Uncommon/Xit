import XCTest


class XitUITests: XCTestCase
{
  let tempDir = TemporaryDirectory("XitTest")
  let app = XCUIApplication(bundleIdentifier: "com.uncommonplace.Xit")
  var repoURL: URL!
  
  override func setUp()
  {
    let repo = TestRepo.testApp
    guard let repoURL = tempDir?.url,
          repo.extract(to: repoURL.path)
    else {
      XCTFail()
      return
    }
    
    self.repoURL = repoURL.appendingPathComponent(repo.rawValue)
  }
  
  override func tearDown()
  {
    NSDocumentController.shared.closeAllDocuments(withDelegate: nil,
                                                  didCloseAllSelector: nil,
                                                  contextInfo: nil)
  }
  
  func assertStagingStatus(workspace: Int, staged: Int)
  {
    let expected = "\(workspace)▸\(staged)"
    let stagingCell = app.outlines["sidebar"].cells.element(boundBy: 1)
    let statusButton = stagingCell.buttons["status"]
    
    XCTAssertEqual(expected, statusButton.title)
  }
  
  func assertBranches(_ branches: [String])
  {
    let sidebar = app.outlines["sidebar"]

    for (index, branch) in branches.enumerated() {
      let cell = sidebar.cells.element(boundBy: index + 3)
      let label = cell.staticTexts.firstMatch.value as? String ?? ""
      
      XCTAssertEqual(label, branch,
                     "item \(index) is '\(label)' instead of '\(branch)'")
    }
  }
  
  func assertCommitFiles(_ names: [String])
  {
    let rows = app.outlines["commitFiles"].outlineRows
    
    for (index, name) in names.enumerated() {
      let label = rows.element(boundBy: index).staticTexts.firstMatch.stringValue
      
      XCTAssertEqual(label, name)
    }
  }
  
  func assertCommitHeader(date: String, sha: String, name: String,
                          parents: [String], message: String)
  {
    let header = app.otherElements["commitInfo"].firstMatch
    let dateField = header.staticTexts["date"].firstMatch
    let shaField = header.staticTexts["sha"].firstMatch
    let nameField = header.staticTexts["name"].firstMatch
    let messageField = header.staticTexts["message"].firstMatch
    let parentFields = header.otherElements["parents"]
                             .staticTexts.allElementsBoundByAccessibilityElement
    
    XCTAssertEqual(dateField.stringValue, date)
    XCTAssertEqual(shaField.stringValue, sha)
    XCTAssertEqual(nameField.stringValue, name)
    XCTAssertEqual(parentFields.map { $0.stringValue }, parents)
    XCTAssertEqual(messageField.stringValue, message)
  }

  func testRepoWindow()
  {
    guard repoURL != nil else { return }

    app.launchArguments = ["-noServices", "YES"]
    app.launch()
    app.activate()
    
    let repoName = TestRepo.testApp.rawValue
    
    NSWorkspace.shared.openFile(repoURL.path, withApplication: "Xit")
    
    let window = app.windows.firstMatch
    
    XCTAssertTrue(window.waitForExistence(timeout: 1.0))
    XCTAssertEqual(window.title, repoName)
    
    let titleView = window.staticTexts.matching(identifier: "titleLabel").firstMatch
    let branchPopup = window.popUpButtons.matching(identifier: "branchPopup").firstMatch

    XCTAssertEqual(titleView.value as? String, repoName)
    XCTAssertEqual(branchPopup.value as? String, "master")
    
    assertStagingStatus(workspace: 1, staged: 0)
    
    assertBranches(["1-and_more", "and-how", "andhow-ad", "asdf", "blah",
                    "feature", "hi!", "master", "new", "other-branch",
                    "wat", "whateelse", "whup",
                    ])

    assertCommitFiles(["README.md", "hero_slide1.png", "jquery-1.8.1.min.js"])
    
    assertCommitHeader(date: "Jan 10, 2013 at 7:11 AM",
                       sha: "a4bca6b67a5483169963572ee3da563da33712f7",
                       name: "Danny Greg <danny@github.com>",
                       parents: ["Rename README."],
                       message: "Add 2 text and 1 binary file for diff tests.")

    // Select a merge commit to test multiple parents
    app.tables["history"].children(matching: .tableRow).element(boundBy: 10).click()
    
    assertCommitHeader(date: "Feb 16, 2012 at 12:10 PM",
                       sha: "d603d61ea756eb881ba440b3e66b561d070aec6e",
                       name: "joshaber <joshaber@gmail.com>",
                       parents: ["Revert ee618c62f57e7807ddee3cd33e0f176d93d015dd^..HEAD",
                                 "evil conflicting commit"],
                       message: "Merge branch 'master' of github.com:github/Test_App")
    
    // Navigate by clicking a parent title
    let header = app.otherElements["commitInfo"].firstMatch

    header.otherElements["parents"].staticTexts.element(boundBy: 0).click()
    
    let parentRow = app.tables["history"].children(matching: .tableRow).element(boundBy: 13)
    
    XCTAssertTrue(parentRow.isSelected)
  }
}

extension XCUIElement
{
  var stringValue: String { value as? String ?? "" }
}
