import XCTest
@testable import Xit

class TeamCityTest: XCTestCase
{  
  override func setUp()
  {
    super.setUp()
  }
  
  override func tearDown()
  {
    super.tearDown()
  }
  
  func parseBuild(statusString: String,
                  status: TeamCityAPI.Build.Status,
                  stateString: String,
                  state: TeamCityAPI.Build.State) throws
  {
    let buildType = "TestBuildType"
    let branchName = "testBranch"
    let sourceXML =
        "<build id=\"45272\" buildTypeId=\"\(buildType)\" " +
        "number=\"XMA-2986_FixBubbleHandles.4261\" status=\"\(statusString)\" " +
        "state=\"\(stateString)\" branchName=\"\(branchName)\" " +
        "href=\"/httpAuth/app/rest/builds/id:45272\" " +
        "webUrl=\"https://teamcity.example.com/viewLog.html?buildId=45272&amp;buildTypeId=\(buildType)\"/>"
    
    let xml = try XMLDocument(xmlString: sourceXML, options: [])
    let build = TeamCityAPI.Build(xml: xml)!
    
    XCTAssertEqual(build.buildType!, buildType)
    XCTAssertEqual(build.status, status)
    XCTAssertEqual(build.state, state)
  }
  
  func testParseBuildFailure() throws
  {
    try parseBuild(statusString: "FAILURE",
                   status: .failed,
                   stateString: "finished",
                   state: .finished)
  }
  
  func testParseBuildSuccess() throws
  {
    try parseBuild(statusString: "SUCCESS",
                   status: .succeeded,
                   stateString: "running",
                   state: .running)
  }
  
  func testBranchSpec()
  {
    let branchSpec = BranchSpec(ruleStrings: [
        "+:refs/heads/develop",
        "+:refs/heads/feature/*",
        "+:refs/heads/fix/(target)",
        "-:refs/heads/skip/*",
        "+:refs/heads/*",
        ])!
    
    XCTAssertEqual(branchSpec.match(branch: "refs/heads/develop"),
                   "refs/heads/develop")
    XCTAssertEqual(branchSpec.match(branch: "refs/heads/thing"), "thing")
    XCTAssertEqual(branchSpec.match(branch: "refs/heads/feature/thing"), "thing")
    XCTAssertEqual(branchSpec.match(branch: "refs/heads/fix/target"), "target")
    XCTAssertNil(branchSpec.match(branch: "refs/heads/skip/rope"))
    
    let defaultSpec = BranchSpec.defaultSpec()
    
    XCTAssertEqual(defaultSpec.match(branch: "refs/heads/master"), "master")
  }
}
