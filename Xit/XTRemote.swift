import Cocoa

public protocol Remote: class
{
  var name: String? { get }
  var urlString: String? { get }
  var pushURLString: String? { get }
  
  func rename(_ name: String) throws
  func updateURLString(_ URLString: String) throws
  func updatePushURLString(_ URLString: String) throws
}

open class XTRemote: GTRemote, Remote
{
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
