import Cocoa

open class XTRemote: GTRemote {

  init?(name: String, repository: XTRepository)
  {
    var gtRemote: OpaquePointer? = nil
    let error = git_remote_lookup(&gtRemote,
                                  repository.gtRepo.git_repository(),
                                  name)
    guard error == 0
    else { return nil }

    super.init(gitRemote: gtRemote!, in: repository.gtRepo)
  }

  // Yes, this override is necessary.
  override init?(gitRemote remote: OpaquePointer, in repo: GTRepository)
  {
    super.init(gitRemote: remote, in: repo)
  }

}
