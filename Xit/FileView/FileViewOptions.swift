import Foundation

struct FileViewOptions
{
  enum Sort: Int
  {
    case path, name, status
  }

  enum Order
  {
    case ascending, descending
  }

  var sort: Sort
  var order: Order

  static var `default`: FileViewOptions
  {
    .init(sort: .path, order: .ascending)
  }

  func sort(changes: inout [FileChange])
  {
    changes.sort { file1, file2 in
      switch sort {
        case .path:
          return file1.path < file2.path
        case .name:
          return file1.path.lastPathComponent < file2.path.lastPathComponent
        case .status:
          return file1.status < file2.status
      }
    }
  }
}
