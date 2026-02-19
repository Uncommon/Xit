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
  func bitbucketHTTPServiceCreatedWithPassword() async throws
  {
    let storage = MemoryPasswordStorage()
    let services = Services(passwordStorage: storage)
    let account = makeAccount(type: .bitbucketServer)
    
    try storage.save(host: account.location.host!,
                     path: account.location.path,
                     port: 80,
                     account: account.user,
                     password: "pw")
    
    let service = services.bitbucketHTTPService(for: account)
    
    try #require(service != nil)
  }
  
  @Test
  func bitbucketHTTPServiceNilWithoutPassword() async throws
  {
    let storage = MemoryPasswordStorage()
    let services = Services(passwordStorage: storage)
    let account = makeAccount(type: .bitbucketServer)
    
    let service = services.bitbucketHTTPService(for: account)
    
    #expect(service == nil)
  }
  
  @Test
  func teamCityHTTPServiceCreatedWithPassword() async throws
  {
    let storage = MemoryPasswordStorage()
    let services = Services(passwordStorage: storage)
    let account = makeAccount(type: .teamCity)
    
    try storage.save(host: account.location.host!,
                     path: account.location.path,
                     port: 80,
                     account: account.user,
                     password: "pw")
    
    let service = services.teamCityHTTPService(for: account)
    
    try #require(service != nil)
  }
}
