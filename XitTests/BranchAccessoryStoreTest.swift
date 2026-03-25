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

  @Test
  func invalidateSpecificRefsAdvancesRevision() throws
  {
    let store = BranchAccessoryStore()
    let start = store.revision

    store.invalidate(refs: ["refs/heads/main"])

    #expect(store.revision == start + 1)
  }

  @Test
  func providerHandlesLocalAndRemoteBranches() throws
  {
    let store = BranchAccessoryStore()
    let local = try #require(LocalBranchRefName.named("main"))
    let remote = try #require(RemoteBranchRefName(remote: "origin",
                                                  branch: "main"))
    var renderedRefs: [String] = []

    store.setProvider { ref in
      renderedRefs.append(ref.fullPath)
      return AnyView(Text(ref.name))
    }

    _ = store.accessory(for: local)
    _ = store.accessory(for: remote)

    #expect(renderedRefs == [local.fullPath, remote.fullPath])
  }
}
