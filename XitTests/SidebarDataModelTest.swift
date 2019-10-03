import XCTest
@testable import Xit

extension SidebarItem
{
  var childrenTitles: [String] { return children.map { $0.title } }
}

class SidebarDataModelTest: XCTestCase
{
  func testLoad()
  {
    let repo = FakeRepo()
    let model = SidebarDataModel(repository: repo, outlineView: nil)
    
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
  
  func testFilter()
  {
    let repo = FakeRepo()
    let model = SidebarDataModel(repository: repo, outlineView: nil)
    
    model.reload()
    XCTAssertEqual(model.rootItem(.branches).children.count, 2)
    
    let branchRoot = model.filteredItem(.branches)
    
    XCTAssertEqual(branchRoot.children.count, 2)

    model.filterString = "1"
    
    let rootNames = model.makeRoots().map { $0.title }
    let filteredNames = model.filteredRoots.map { $0.title }
    let branches = model.filteredItem(.branches)
    let remotes = model.filteredItem(.remotes)
    
    XCTAssertEqual(filteredNames, rootNames)
    XCTAssertEqual(branches.childrenTitles, ["branch1"])
    XCTAssertEqual(remotes.childrenTitles, ["origin1", "origin2"])
    XCTAssertEqual(remotes.children[0].childrenTitles, ["branch1"])
    XCTAssertEqual(remotes.children[1].childrenTitles, [])
  }
}
