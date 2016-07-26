import XCTest
@testable import Xit

class XTTeamCityTest: XCTestCase {
  
  override func setUp()
  {
    super.setUp()
  }
  
  override func tearDown()
  {
    super.tearDown()
  }
  
  func parseBuild(statusString statusString: String,
                  status: XTTeamCityAPI.Build.Status,
                  stateString: String,
                  state: XTTeamCityAPI.Build.State)
  {
    let buildType = "TestBuildType"
    let branchName = "testBranch"
    let sourceXML =
        "<build id=\"45272\" buildTypeId=\"\(buildType)\" " +
        "number=\"XMA-2986_FixBubbleHandles.4261\" status=\"\(statusString)\" " +
        "state=\"\(stateString)\" branchName=\"\(branchName)\" " +
        "href=\"/httpAuth/app/rest/builds/id:45272\" " +
        "webUrl=\"https://teamcity.example.com/viewLog.html?buildId=45272&amp;buildTypeId=\(buildType)\"/>"
    
    let xml = try! NSXMLDocument(XMLString: sourceXML, options: 0)
    let build = XTTeamCityAPI.Build(xml: xml)!
    
    XCTAssertEqual(build.buildType!, buildType)
    XCTAssertEqual(build.status, status)
    XCTAssertEqual(build.state, state)
  }
  
  func testParseBuildFailure()
  {
    parseBuild(statusString: "FAILURE",
               status: .Failed,
               stateString: "finished",
               state: .Finished)
  }
  
  func testParseBuildSuccess()
  {
    parseBuild(statusString: "SUCCESS",
               status: .Succeeded,
               stateString: "running",
               state: .Running)
  }
}
