import Foundation
import Testing
@testable import Xit

@Suite("TeamCityHTTPService")
struct TeamCityHTTPServiceTests
{
  private func makeService(mock: MockNetworkService) -> TeamCityHTTPService
  {
    let account = Account(type: .teamCity,
                          user: "user",
                          location: URL(string: "https://example.com")!,
                          id: UUID())

    return TeamCityHTTPService(account: account,
                               password: "pw",
                               passwordStorage: MemoryPasswordStorage.shared,
                               authenticationPath: TeamCityHTTPService.rootPath,
                               networkService: mock)
  }

  @Test
  func parseBuildTypes() async throws
  {
    let mock = MockNetworkService()
    let service = makeService(mock: mock)

    let xml = """
        <buildTypes>
          <buildType id="bt1" name="Build One" projectName="Proj1"/>
          <buildType id="bt2" name="Build Two" projectName="Proj2"/>
        </buildTypes>
        """.data(using: .utf8)!

    mock.setNextResponse(data: xml)

    let types = try await service.loadBuildTypes()

    try #require(types.count >= 1)
    #expect(types[0].id == "bt1")
    #expect(types[0].projectName == "Proj1")
    try #require(types.count == 2)
    #expect(types[1].id == "bt2")
    #expect(types[1].projectName == "Proj2")
  }

  @Test
  func parseBuilds() async throws
  {
    let mock = MockNetworkService()
    let service = makeService(mock: mock)

    let xml = """
        <builds>
          <build id="1" number="42" buildTypeId="bt1" status="SUCCESS" state="finished" percentageComplete="100" webUrl="https://example.com/build/1" />
          <build id="2" number="43" buildTypeId="bt1" status="FAILURE" state="finished" webUrl="https://example.com/build/2" />
        </builds>
        """.data(using: .utf8)!

    mock.setNextResponse(data: xml)

    let builds = try await service.loadBuilds(buildTypeID: "bt1")

    try #require(builds.count >= 1)
    #expect(builds[0].id == 1)
    #expect(builds[0].status == .succeeded)
    try #require(builds.count == 2)
    #expect(builds[1].id == 2)
    #expect(builds[1].status == .failed)
  }

  @Test
  func parseVCSRootsAndBranches() async throws
  {
    let mock = MockNetworkService()
    let service = makeService(mock: mock)

    let rootsList = """
        <vcs-roots>
          <vcs-root id="root1" />
        </vcs-roots>
        """.data(using: .utf8)!

    let rootDetail = """
        <vcs-root id="root1">
          <properties>
            <property name="url" value="https://example.com/repo.git" />
            <property name="teamcity:branchSpec" value="+:refs/heads/*" />
          </properties>
        </vcs-root>
        """.data(using: .utf8)!

    mock.responseQueue = [.success(rootsList), .success(rootDetail)]

    try await service.loadVCSRoots()

    let rootURL = service.vcsRootURLSnapshot(for: "root1")
    let branchSpec = service.branchSpecSnapshot(for: "root1")

    #expect(rootURL == URL(string: "https://example.com/repo.git"))
    #expect(branchSpec?.match(branch: "refs/heads/main") == "main")
  }

  @Test
  func refreshBuildTypesPopulatesMappings() async throws
  {
    let mock = MockNetworkService()
    let service = makeService(mock: mock)

    let rootsList = """
        <vcs-roots>
          <vcs-root id="root1" />
        </vcs-roots>
        """.data(using: .utf8)!

    let rootDetail = """
        <vcs-root id="root1">
          <properties>
            <property name="url" value="https://example.com/repo.git" />
            <property name="teamcity:branchSpec" value="+:refs/heads/*" />
          </properties>
        </vcs-root>
        """.data(using: .utf8)!

    let buildTypesXML = """
        <buildTypes>
          <buildType id="bt1" name="Build One" projectName="Proj1"/>
        </buildTypes>
        """.data(using: .utf8)!

    let buildTypeDetail = """
        <buildType id="bt1" name="Build One" projectName="Proj1">
          <vcs-root-entries>
            <vcs-root-entry id="root1" />
          </vcs-root-entries>
        </buildType>
        """.data(using: .utf8)!

    mock.responseQueue = [
      .success(rootsList),
      .success(rootDetail),
      .success(buildTypesXML),
      .success(buildTypeDetail)
    ]

    await service.refreshMetadata()

    let cached = service.cachedBuildTypesSnapshot()
    let urls = service.buildTypeURLsSnapshot(for: "bt1")

    #expect(await MainActor.run { service.buildTypesStatus == .done })
    #expect(cached.count == 1)
    #expect(urls?.first == URL(string: "https://example.com/repo.git"))
    #expect(await service.buildTypesForRemote("https://example.com/repo.git") == ["bt1"])
  }
}
