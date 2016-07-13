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
  
  var name: String { return tag.name }
  var message: String { return tag.message }
  var targetSHA: String? { return tag.target?.SHA }
}
