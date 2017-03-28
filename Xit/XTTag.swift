import Cocoa

let tagPrefix = "refs/tags/"

class XTTag
{
  unowned let repository: XTRepository
  private let tag: GTTag?
  /// Tag name (without "refs/tags/")
  let name: String
  let targetSHA: String?
  /// Tag message; will be nil for lightweight tags.
  var message: String? { return tag?.message }
  
  init(repository: XTRepository, tag: GTTag)
  {
    self.repository = repository
    self.tag = tag
    self.name = tag.name
    self.targetSHA = tag.target!.sha!
  }
  
  /// Initialize with the given tag name.
  /// - parameter name: Can be either fully qualified with `refs/tags/`
  /// or just the tag name itself.
  init?(repository: XTRepository, name: String)
  {
    let refName = name.hasPrefix(tagPrefix) ? name : tagPrefix + name
  
    self.repository = repository
    self.name = name.removingPrefix(tagPrefix)
    
    guard let ref = try? repository.gtRepo.lookUpReference(withName: refName)
    else { return nil }
    
    // If it doesn't resolve as a tag, then it's a lightweight tag pointing
    // directly at the commit.
    switch ref.unresolvedTarget {
      
      case let tag as GTTag:
        self.tag = tag
        self.targetSHA = tag.target!.sha
      
      case let commit as GTCommit:
        self.tag = nil
        self.targetSHA = commit.sha
      
      default:
        return nil
    }
    
    if targetSHA == nil {
      NSLog("Tag \(name) has no target SHA")
    }
  }
}
