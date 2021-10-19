import Cocoa

public protocol Tag
{
  /// Tag name (without "refs/tags/")
  var name: String { get }
  var targetOID: OID? { get }
  var commit: Commit? { get }
  /// Tag message; will be nil for lightweight tags.
  var message: String? { get }
}

public final class GitTag: Tag
{
  // TODO: Move this out because it's used by other classes
  static let tagPrefix = "refs/tags/"

  let repository: XTRepository
  private let ref: OpaquePointer
  private let tag: OpaquePointer?
  public let name: String
  public lazy var targetOID: OID? = self.calculateOID()
  public lazy var message: String? = self.calculateMessage()
  public var commit: Commit?
  { targetOID.flatMap { repository.commit(forOID: $0) } }
  
  /// Initialize with the given tag name.
  /// - parameter name: Can be either fully qualified with `refs/tags/`
  /// or just the tag name itself.
  init?(repository: XTRepository, name: String)
  {
    let refName = name.hasPrefix(GitTag.tagPrefix) ? name : GitTag.tagPrefix + name
    guard let ref = try? OpaquePointer.from({
            git_reference_lookup(&$0, repository.gitRepo, refName)
          }),
          git_reference_is_tag(ref) == 1
    else { return nil }
    
    self.ref = ref
    self.name = name.droppingPrefix(GitTag.tagPrefix)
    
    self.tag = try? OpaquePointer.from({
        git_reference_peel(&$0, ref, GIT_OBJECT_TAG) })
    self.repository = repository
  }
  
  deinit
  {
    git_reference_free(self.ref)
    self.tag.map { git_tag_free($0) }
  }
  
  func calculateMessage() -> String?
  {
    return tag.flatMap { String(cString: git_tag_message($0)) }
  }
  
  func calculateOID() -> OID?
  {
    if let tag = self.tag {
      return GitOID(oid: git_tag_target_id(tag).pointee)
    }
    
    guard let target = try? OpaquePointer.from({
      git_reference_peel(&$0, ref, GIT_OBJECT_COMMIT)
    })
    else { return nil }
    
    return GitOID(oid: git_commit_id(target).pointee)
  }
}
