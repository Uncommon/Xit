import Foundation
import Testing
@testable import Xit

@Suite("ServicesManager")
struct ServicesManagerTests
{
  private func makeAccount(type: AccountType, host: String = "example.com") -> Account
  {
    Account(type: type,
            user: "user",
            location: URL(string: "http://\(host)")!,
            id: UUID())
  }
  
  @Test
  func hasNoPullRequestProviderByDefault() async
  {
    let services = Services(passwordStorage: MemoryPasswordStorage())
    
    #expect(services.hasPullRequestService == false)
    #expect(services.pullRequestService(forID: UUID()) == nil)
  }
  
  @Test
  func teamCityServiceCreatedWithPassword() async throws
  {
    let storage = MemoryPasswordStorage()
    let services = Services(passwordStorage: storage)
    let account = makeAccount(type: .teamCity)
    
    try storage.save(host: account.location.host!,
                     path: account.location.path,
                     port: 80,
                     account: account.user,
                     password: "pw")
    
    let service = services.teamCityService(for: account)
    
    try #require(service != nil)
  }
}
