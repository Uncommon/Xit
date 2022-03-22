import Foundation

protocol ObjectDatabase
{
  subscript(oid: any OID) -> ODBObject? { get }
}

protocol ODBObject
{
  var text: String { get }
}

class GitODB: ObjectDatabase
{
  let odb: OpaquePointer

  init?(repository: OpaquePointer)
  {
    do {
      self.odb = try OpaquePointer.from {
        git_repository_odb(&$0, repository)
      }
    }
    catch {
      return nil
    }
  }

  deinit
  {
    git_odb_free(odb)
  }

  subscript(oid: any OID) -> (any ODBObject)?
  {
    guard let gitOID = oid as? GitOID,
          let object = try? OpaquePointer.from({ item in
            gitOID.withUnsafeOID { unsafeOID in
              git_odb_read(&item, odb, unsafeOID)
            }
          })
    else {
      return nil
    }

    return GitODBObject(object: object)
  }

  subscript(oid: git_oid) -> GitODBObject?
  {
    var oid = oid // need mutable copy
    guard let object = try? OpaquePointer.from({
      git_odb_read(&$0, odb, &oid)
    })
    else { return nil }

    return GitODBObject(object: object)
  }
}

class GitODBObject: ODBObject
{
  let object: OpaquePointer

  var text: String
  {
    guard let buf = git_odb_object_data(object)
    else { return "" }

    return String(cString: buf.assumingMemoryBound(to: CChar.self))
  }

  var data: Data
  {
    guard let buf = git_odb_object_data(object)
    else { return Data() }
    let size = git_odb_object_size(object)

    return Data(immutableBytesNoCopy: buf, count: size, deallocator: .none)
      ?? .init()
  }

  init(object: OpaquePointer)
  {
    self.object = object
  }

  deinit
  {
    git_odb_object_free(object)
  }
}
