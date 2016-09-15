import Cocoa

class XTSubmodule: NSObject {

  unowned let reepository: XTRepository
  let sub: GTSubmodule
  
  init(repository: XTRepository, submodule: GTSubmodule)
  {
    self.reepository = repository
    self.sub = submodule
    
    super.init()
  }
  
  var name: String? { return sub.name }
  var path: String? { return sub.path }
  var URLString: String? { return sub.urlString }
}
