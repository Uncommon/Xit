import XCTest
@testable import Xit

class SidebarDataModelTest: XCTestCase
{
  func testLoad()
  {
    let repo = FakeRepo()
    let controller = FakeRepoController(repository: repo)
    let model = SidebarDataModel(repository: repo, outlineView: nil)

    _ = controller.repository // kill the warning
    model.reload()

    XCTAssertEqual(model.roots.map { $0.title },
                   ["Workspace", "Branches", "Remotes", "Tags",
                    "Stashes", "Submodules"])
    XCTAssertEqual(model.rootItem(.workspace).childrenTitles, ["Staging"])
    XCTAssertEqual(model.rootItem(.branches).childrenTitles,
                   ["branch1", "branch2"])
    XCTAssertEqual(model.rootItem(.remotes).childrenTitles,
                   ["origin1", "origin2"])
    XCTAssertEqual(model.rootItem(.remotes).children[0].childrenTitles,
                   ["branch1"])
    XCTAssertEqual(model.rootItem(.remotes).children[1].childrenTitles,
                   ["branch2"])
  }
}
