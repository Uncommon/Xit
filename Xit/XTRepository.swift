import Foundation


extension XTRepository {
  
  /// Initiates pulling the given branch.
  /// - parameter branch: Either the local branch or the remote tracking branch.
  /// - parameter remote: The remote to pull from.
  /// - parameter options: Options for fetch.
  /// - parameter progressBlock: Progress callback. Return true to stop.
  public func pullBranch(branch: XTBranch,
                         remote: XTRemote,
                         options: [String: AnyObject],
                         progressBlock: (git_transfer_progress) -> Bool) throws
  {
    try gtRepo.pullBranch(branch.gtBranch, fromRemote: remote, withOptions: options) {
      (progress: UnsafePointer<git_transfer_progress>,
       stop: UnsafeMutablePointer<ObjCBool>) in
      stop.memory = ObjCBool(progressBlock(progress.memory))
    }
  }
}