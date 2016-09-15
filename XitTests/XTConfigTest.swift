import XCTest
@testable import Xit

class XTConfigTest: XTTest {
  
  func testTeamCity()
  {
    let remoteName = "origin"
    let config = repository.config
    guard let xitConfigURL = config.xitConfigURL
    else {
      XCTFail("Can't get config URL")
      return
    }
    
    XCTAssertFalse(xitConfigURL.checkResourceIsReachableAndReturnError(nil))
    XCTAssertNil(config.teamCityAccount(remoteName))
    
    let account = Account(type: .TeamCity,
                          user: "User",
                          location: URL(string: "http://teamcity/path")!)
    
    config.setTeamCityAccount(remoteName, account: account)
    config.saveXitConfig()
    
    XCTAssertTrue(xitConfigURL.checkResourceIsReachableAndReturnError(nil))
    
    let configDict = NSDictionary(contentsOfURL: xitConfigURL)!
    
    XCTAssertEqual(configDict["remote.origin.teamCityAccount"] as? String,
                   "http://User@teamcity/path")
    
    let newConfig = XTConfig(repository: repository)
    
    newConfig.loadXitConfig()
    
    let newAccount = newConfig.teamCityAccount(remoteName)!
    
    XCTAssertEqual(newAccount.type, AccountType.TeamCity)
    XCTAssertEqual(newAccount.user, account.user)
    XCTAssertEqual(newAccount.location, account.location)
  }
  
}
