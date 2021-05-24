import Foundation
import XCTest

let XitApp = XCUIApplication(bundleIdentifier: "com.uncommonplace.Xit")

enum Window
{
  static let window = XitApp.windows["repoWindow"].firstMatch
  static let remoteOpSegControl = window.toolbars.groups["Remote Operations"]
  static let pullButton = remoteOpSegControl.buttons.element(boundBy: 0)
  static let pushButton = remoteOpSegControl.buttons.element(boundBy: 1)
  static let fetchButton = remoteOpSegControl.buttons.element(boundBy: 2)
  static let progressSpinner = window.progressIndicators["progress"]
  static let branchPopup = window.popUpButtons["branchPopup"]
  static let tabStatus = window.buttons["tabStatus"]
  
  static let pullMenu = XitApp.menus["pullPopup"]
  static let pushMenu = XitApp.menus["pushPopup"]
  static let fetchMenu = XitApp.menus["fetchPopup"]
}

enum PrefsWindow
{
  static let window = XitApp.windows["Preferences"]
  static let generalTab = window.toolbars.buttons["General"]
  
  static let tabStatusCheck = window.checkBoxes["tabStatus"]
  
  static func open(file: StaticString = #file, line: UInt = #line)
  {
    let menuBar = XitApp.menuBars
    
    menuBar.menuBarItems["Xit"].click()
    menuBar.menuItems["Preferences…"].click()
    XCTAssertTrue(window.waitForExistence(timeout: 1.0),
                  "Preferences window did not open", file: file, line: line)
  }
  
  static func close()
  {
    if window.exists {
      window.buttons[XCUIIdentifierCloseWindow].click()
    }
  }
}

enum Sidebar
{
  static let list = Window.window.outlines["sidebar"]
  static let filter = Window.window.searchFields["sidebarFilter"]
  static let addButton = Window.window.popUpButtons["sidebarAdd"]
  static let stagingCell = list.cells.element(boundBy: 1)
  
  static func cell(named name: String) -> XCUIElement
  {
    return list.cells.containing(.staticText, identifier: name).firstMatch
  }
  
  static func assertStagingStatus(workspace: Int, staged: Int)
  {
    let expected = "\(workspace)▸\(staged)"
    let statusButton = stagingCell.buttons["workspaceStatus"]
    
    XCTAssertEqual(expected, statusButton.title)
  }
  
  static func assertBranches(_ branches: [String])
  {
    for (index, branch) in branches.enumerated() {
      let cell = list.cells.element(boundBy: index + 3)
      let label = cell.staticTexts.firstMatch.value as? String ?? ""
      
      XCTAssertEqual(label, branch,
                     "item \(index) is '\(label)' instead of '\(branch)'")
    }
  }
  
  static func workspaceStatusIndicator(branch: String) -> XCUIElement
  {
    let cell = Sidebar.list.cells.containing(.staticText, identifier: branch)
    
    return cell.buttons["workspaceStatus"]
  }
  
  static func trackingStatusIndicator(branch: String) -> XCUIElement
  {
    let cell = Sidebar.list.cells.containing(.staticText, identifier: branch)
    
    return cell.buttons["trackingStatus"]
  }
}

enum CommitHeader
{
  static let header = XitApp.groups["commitInfo"].firstMatch
  static let dateField = header.staticTexts["date"].firstMatch
  static let shaField = header.links["sha"].firstMatch
  static let nameField = header.staticTexts["name"].firstMatch
  static let emailField = header.staticTexts["email"].firstMatch
  static let messageField = header.staticTexts["message"].firstMatch
  static var parentFields: [XCUIElement]
  {
    header.groups["parents"]
          .staticTexts.matching(identifier: "parent")
          .allElementsBoundByAccessibilityElement
  }
  
  static func parentField(_ index: Int) -> XCUIElement
  {
    header.groups["parents"]
          .staticTexts.matching(identifier: "parent")
          .element(boundBy: index)
  }
  
  static func assertDisplay(date: String, sha: String,
                            name: String, email: String,
                            parents: [String], message: String)
  {
    XCTAssertEqual(dateField.stringValue, date)
    XCTAssertEqual(shaField.label, sha)
    XCTAssertEqual(nameField.stringValue, name)
    XCTAssertEqual(emailField.stringValue, email)
    XCTAssertEqual(parentFields.map { $0.stringValue }, parents)
    XCTAssertEqual(messageField.stringValue, message)
  }
}

enum CommitEntry
{
  static let messageField = XitApp.textViews["messageField"].firstMatch
  static let commitButton = XitApp.buttons["commitButton"].firstMatch
  static let amendCheck = XitApp.checkBoxes["amendCheck"].firstMatch
  static let stripCheck = XitApp.checkBoxes["stripCheck"].firstMatch
}

protocol FileList
{
  static var list: XCUIElement { get }
}

extension FileList
{
  static func assertFiles(_ names: [String],
                          file: StaticString = #file,
                          line: UInt = #line)
  {
    let rows = list.outlineRows
    let rowCount = rows.count
    guard names.count == rowCount
    else {
      XCTFail("expected \(names.count) files, found \(rowCount)",
              file: file, line: line)
      return
    }

    for (index, name) in names.enumerated() {
      let label = rows.element(boundBy: index).staticTexts.firstMatch.stringValue
      
      XCTAssertEqual(label, name, "file \(index) does not match",
                     file: file, line: line)
    }
  }
}

enum CommitFileList: FileList
{
  static let list = XitApp.outlines["commitFiles"]
}

enum StagedFileList: FileList
{
  static let list = XitApp.outlines["stagedFiles"]
  
  static let refreshButton = Window.window.buttons["WorkspaceRefresh"]
}

enum WorkspaceFileList: FileList
{
  static let list = XitApp.outlines["workspaceFiles"]
}

enum HistoryList
{
  static let list = XitApp.tables["history"]

  static func row(_ index: Int) -> XCUIElement
  {
    return list.tableRows.element(boundBy: index)
  }
  
  enum ContextMenu
  {
    static let menu = XitApp.menus["HistoryMenu"]
    static let copySHAItem = menu.menuItems["Copy SHA"]
    static let resetItem = menu.menuItems["Reset to this commit..."]
  }
}

enum ResetSheet
{
  static let window = XitApp.sheets["ResetSheet"]
  
  // Why these are exposed as radio buttons instead of a segmented control
  // is a mystery.
  static let softButton = window.radioButtons["Soft"]
  static let mixedButton = window.radioButtons["Mixed"]
  static let hardButton = window.radioButtons["Hard"]
  
  static let modeDescription = window.staticTexts["Description"]
  static let statusText = window.staticTexts["Status"]
  
  static let cancelButton = window.buttons["Cancel"]
  static let resetButton = window.buttons["Reset"]
}

enum PushNewSheet
{
  static let window = XitApp.sheets["PushNewSheet"]
  
  static let setTrackingCheck = window.checkBoxes["Set as tracking branch"]
  static let pushButton = window.buttons["Push"]
}
