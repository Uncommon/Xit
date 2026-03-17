import SwiftUI
import Testing
@testable import Xit

@MainActor
struct BranchAccessoryStoreTest
{
  @Test
  func invalidateAdvancesRevision() throws
  {
    let store = BranchAccessoryStore()
    let start = store.revision

    store.invalidate()

    #expect(store.revision == start + 1)
  }

  @Test
  func setProviderInvalidatesStore() throws
  {
    let store = BranchAccessoryStore()
    let ref = try #require(LocalBranchRefName.named("main"))
    let start = store.revision

    store.setProvider { _ in AnyView(Text("Accessory")) }
    _ = store.accessory(for: ref)

    #expect(store.revision == start + 1)
  }
}
