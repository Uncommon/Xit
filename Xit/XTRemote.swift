import Cocoa

public class XTRemote: GTRemote {

  init?(name: String, repository: XTRepository)
  {
    var gtRemote: COpaquePointer = nil
    let error = git_remote_lookup(&gtRemote,
                                  repository.gtRepo.git_repository(),
                                  name)
    guard error == 0
    else { return nil }

    super.init(gitRemote: gtRemote, inRepository: repository.gtRepo)
  }

}
