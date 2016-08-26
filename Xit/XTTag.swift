import Cocoa

class XTTag: NSObject {

  unowned let repository: XTRepository
  let tag: GTTag
  
  init(repository: XTRepository, tag: GTTag)
  {
    self.repository = repository
    self.tag = tag
    
    super.init()
  }
  
  init?(repository: XTRepository, name: String)
  {
    self.repository = repository
    
    guard let ref = try? repository.gtRepo.lookUpReferenceWithName(name)
    else { return nil }
    
    guard let target = ref.resolvedTarget as? GTTag
    else { return nil }
    
    tag = target
  }
  
  var name: String { return tag.name }
  var message: String { return tag.message }
  var targetSHA: String? { return tag.target?.SHA }
}
