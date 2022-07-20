import XCTest
@testable import Xit

class ServicesTest: XCTestCase
{
  func testEmpty()
  {
    let services = Services(passwordStorage: NoOpKeychain())
    let location = URL(string: "http://example.com")!

    XCTAssert(services.allServices.isEmpty)

    for type in AccountType.allCases {
      let account = Account(type: type,
                            user: "Guy",
                            location: location,
                            id: .init())

      XCTAssertNil(services.service(for: account))
    }
  }

  func testSingleService()
  {
    let location = URL(string: "http://example.com")!

    for serviceAccountType in AccountType.allCases {
      let services = Services(passwordStorage: NoOpKeychain())

      services.serviceMakers[serviceAccountType] = MockAuthService.init

      for accountType in AccountType.allCases {
        let account = Account(type: accountType,
                              user: "Guy",
                              location: location,
                              id: .init())
        let result = services.service(for: account)

        if serviceAccountType == accountType {
          XCTAssert(result is MockAuthService)
        }
        else {
          XCTAssertNil(result)
        }
      }
    }
  }

  func testMultipleServices()
  {
    let githubAccount = Account(type: .gitHub,
                                user: "gh",
                                location: .init(string: "http://github.com")!,
                                id: .init())
    let gitlabAccount = Account(type: .gitLab,
                                user: "gl",
                                location: .init(string: "http://gitlab.com")!,
                                id: .init())
    let bitbucketAccount = Account(type: .bitbucketCloud,
                                   user: "bb",
                                   location: .init(string: "http:bitbucket.com")!,
                                   id: .init())
    let githubService = MockAuthService(account: githubAccount)
    let gitlabService = MockAuthService(account: gitlabAccount)
    let bitbucketService = MockAuthService(account: bitbucketAccount)
    let services = Services(passwordStorage: NoOpKeychain())

    services.serviceMakers[.gitHub] = { _ in githubService }
    services.serviceMakers[.gitLab] = { _ in gitlabService }
    services.serviceMakers[.bitbucketCloud] = { _ in bitbucketService }

    XCTAssert(services.service(for: githubAccount) === githubService)
    XCTAssert(services.service(for: gitlabAccount) === gitlabService)
    XCTAssert(services.service(for: bitbucketAccount) === bitbucketService)
  }
}
