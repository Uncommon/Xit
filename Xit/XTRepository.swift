import Foundation

extension XTRepository {
  
  func stashes() -> [XTStash]
  {
    var stashes = [XTStash]()
    
    // All we really need is the number of stashes,
    // but there is no call that does that.
    gtRepo.enumerateStashesUsingBlock { (index, message, oid, stop) in
      stashes.append(XTStash(repo: self, index: index, message: message))
    }
    return stashes
  }
  
  func submodules() -> [XTSubmodule]
  {
    var submodules = [XTSubmodule]()
    
    gtRepo.enumerateSubmodulesRecursively(false) {
      (submodule, error, stop) in
      if let submodule = submodule {
        submodules.append(XTSubmodule(repository: self, submodule: submodule))
      }
    }
    return submodules
  }
  
  /// Returns the list of tags, or throws if libgit2 hit an error.
  func tags() throws -> [XTTag]
  {
    let tags = try gtRepo.allTags()
    
    return tags.map({ XTTag(repository: self, tag: $0) })
  }
}