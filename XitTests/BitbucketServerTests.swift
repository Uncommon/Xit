import XCTest
@testable import Xit

class BitbucketServerTests: XCTestCase
{
  func testUserData()
  {
    let link = BitbucketServer.Link(href: "https://stash.example.com/users/guy",
                                    name: nil)
    let links = BitbucketServer.Links(self: [link], clone: nil)
    let user = BitbucketServer.User(name: "Guy",
                                    emailAddress: "feeble@example.com",
                                    id: 8192, displayName: "Guy Feeble",
                                    active: true, slug: "guy",
                                    type: .normal,
                                    links: links)
    let json = """
        {"name":"\(user.name)","emailAddress":"\(user.emailAddress)",\
        "id":\(user.id),"displayName":"\(user.displayName)",\
        "active":\(user.active),"slug":"\(user.slug)",\
        "type":"\(user.type.rawValue)","links":{"self":\
        [{"href":"\(user.links!.`self`[0].href ?? "!")"}]}}
        """
    guard let data = json.data(using: .utf8)
    else {
      XCTFail("utf8 failure")
      return
    }
    
    let decoder = JSONDecoder()

    do {
      let decoded = try decoder.decode(BitbucketServer.User.self, from: data)

      XCTAssertEqual(decoded, user)
    }
    catch let error as DecodingError {
      XCTFail("Decoding error")
      print(error.context.debugDescription)
    }
    catch {
      XCTFail("Decoding error")
    }
  }
}
