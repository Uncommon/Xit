import XCTest
@testable import Xit

class XTConfigTest: XTTest {
  
  func testTeamCity()
  {
    let remoteName = "origin"
    let config = repository.config
    guard let xitConfigURL: URL = config.xitConfigURL
    else {
      XCTFail("Can't get config URL")
      return
    }
    
    XCTAssertFalse(try! xitConfigURL.checkResourceIsReachable())
    XCTAssertNil(config.teamCityAccount(remoteName))
    
    let account = Account(type: .teamCity,
                          user: "User",
                          location: URL(string: "http://teamcity/path")!)
    
    config.setTeamCityAccount(remoteName, account: account)
    config.saveXitConfig()
    
    XCTAssertTrue(try! xitConfigURL.checkResourceIsReachable())
    
    let configDict = NSDictionary(contentsOf: xitConfigURL)!
    
    XCTAssertEqual(configDict["remote.origin.teamCityAccount"] as? String,
                   "http://User@teamcity/path")
    
    let newConfig = XTConfig(repository: repository)
    
    newConfig.loadXitConfig()
    
    let newAccount = newConfig.teamCityAccount(remoteName)!
    
    XCTAssertEqual(newAccount.type, AccountType.teamCity)
    XCTAssertEqual(newAccount.user, account.user)
    XCTAssertEqual(newAccount.location, account.location)
  }
  
}
