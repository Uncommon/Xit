import Foundation

protocol Config
{
  subscript(index: String) -> Bool? { get set }
  subscript(index: String) -> String? { get set }
  subscript(index: String) -> Int? { get set }
}

class GitConfig: Config
{
  let config: OpaquePointer
  
  init?(repository: OpaquePointer)
  {
    let config = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
    let result = git_repository_config(config, repository)
    guard result == 0,
          let finalConfig = config.pointee
    else { return nil }
    
    self.config = finalConfig
  }
  
  deinit
  {
    git_config_free(config)
  }
  
  subscript(index: String) -> Bool?
  {
    get
    {
      let b = UnsafeMutablePointer<Int32>.allocate(capacity: 1)
      let result = git_config_get_bool(b, config, index)
      guard result == 0
      else { return nil }
      
      return b.pointee != 0
    }
    set
    {
      if let value = newValue {
        git_config_set_bool(config, index, value ? 1 : 0)
      }
      else {
        git_config_delete_entry(config, index)
      }
    }
  }
  
  subscript(index: String) -> String?
  {
    get
    {
      let string = UnsafeMutablePointer<UnsafePointer<Int8>?>.allocate(capacity: 1)
      let result = git_config_get_string(string, config, index)
      guard result == 0,
            let finalString = string.pointee
      else { return nil }
      
      return String(cString: finalString)
    }
    set
    {
      if let value = newValue {
        git_config_set_string(config, index, value)
      }
      else {
        git_config_delete_entry(config, index)
      }
    }
  }
  
  subscript(index: String) -> Int?
  {
    get
    {
      let b = UnsafeMutablePointer<Int32>.allocate(capacity: 1)
      let result = git_config_get_int32(b, config, index)
      guard result == 0
      else { return nil }
      
      return Int(b.pointee)
    }
    set
    {
      if let value = newValue {
        git_config_set_int32(config, index, Int32(value))
      }
      else {
        git_config_delete_entry(config, index)
      }
    }
  }
}
