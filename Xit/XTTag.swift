import Cocoa

let tagPrefix = "refs/tags/"

class XTTag: NSObject {

  unowned let repository: XTRepository
  let tag: GTTag
  
  init(repository: XTRepository, tag: GTTag)
  {
    self.repository = repository
    self.tag = tag
    
    super.init()
  }
  
  /// Initialize with the given tag name.
  /// - parameter name: Can be either fully qualified with `refs/tags/`
  /// or just the tag name itself.
  init?(repository: XTRepository, name: String)
  {
    let refName = name.hasPrefix(tagPrefix) ? name : tagPrefix + name
  
    self.repository = repository
    
    guard let ref = try? repository.gtRepo.lookUpReference(withName: refName)
    else { return nil }
    
    guard let target = ref.unresolvedTarget as? GTTag
    else { return nil }
    
    tag = target
  }
  
  var name: String { return tag.name }
  var message: String { return tag.message }
  var targetSHA: String? { return tag.target?.sha }
}
