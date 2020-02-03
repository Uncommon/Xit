import Foundation
import XCTest

let XitApp = XCUIApplication(bundleIdentifier: "com.uncommonplace.Xit")

enum Window
{
  static let window = XitApp.windows["repoWindow"].firstMatch
  static let titleLabel = window.staticTexts["titleLabel"]
  static let branchPopup = window.popUpButtons["branchPopup"]
  static let tabStatus = window.buttons["tabStatus"]
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
    XCTAssertTrue(window.waitForExistence(timeout: 1.0), file: file, line: line)
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
}

enum CommitHeader
{
  static let header = XitApp.otherElements["commitInfo"].firstMatch
  static let dateField = header.staticTexts["date"].firstMatch
  static let shaField = header.staticTexts["sha"].firstMatch
  static let nameField = header.staticTexts["name"].firstMatch
  static let messageField = header.staticTexts["message"].firstMatch
  static var parentFields: [XCUIElement]
  { header.otherElements["parents"]
          .staticTexts.allElementsBoundByAccessibilityElement }
  
  static func parentField(_ index: Int) -> XCUIElement
  {
    return header.otherElements["parents"].staticTexts.element(boundBy: index)
  }
  
  static func assertDisplay(date: String, sha: String, name: String,
                            parents: [String], message: String)
  {
    XCTAssertEqual(dateField.stringValue, date)
    XCTAssertEqual(shaField.stringValue, sha)
    XCTAssertEqual(nameField.stringValue, name)
    XCTAssertEqual(parentFields.map { $0.stringValue }, parents)
    XCTAssertEqual(messageField.stringValue, message)
  }
}

enum CommitFileList
{
  static let list = XitApp.outlines["commitFiles"]
  
  static func assertFiles(_ names: [String])
  {
    let rows = list.outlineRows
    
    for (index, name) in names.enumerated() {
      let label = rows.element(boundBy: index).staticTexts.firstMatch.stringValue
      
      XCTAssertEqual(label, name)
    }
  }
}

enum HistoryList
{
  static let list = XitApp.tables["history"]
  
  static func row(_ index: Int) -> XCUIElement
  {
    return list.tableRows.element(boundBy: index)
  }
}
