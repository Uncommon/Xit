import Foundation
import os

enum Signpost
{
  static let logger = OSLog(subsystem: "com.uncommonplace.xit",
                              category: "Xit: loading")

  enum Event
  {
    case windowControllerLoad
    case postIndexChanged
    case detectIndexChanged
    
    var name: StaticString
    {
      switch self {
        case .windowControllerLoad: return "window controller load"
        case .postIndexChanged: return "post index changed"
        case .detectIndexChanged: return "detect index changed"
      }
    }
  }

  enum Interval
  {
    case historyWalking
    case connectCommits
    case generateConnections(Int)
    case generateLines(Int)
    case sidebarReload
    case loadIndex
    case loadWorkspace
    case loadTags
    
    var name: StaticString
    {
      switch self {
        case .historyWalking: return "history walking"
        case .connectCommits: return "connect commits"
        case .generateConnections: return "generate connenctions"
        case .generateLines: return "generate lines"
        case .sidebarReload: return "sidebar reload"
        case .loadIndex: return "load index"
        case .loadWorkspace: return "load workspace"
        case .loadTags: return "load tags"
      }
    }
  }

  static func event(_ code: Event)
  {
    os_signpost(.event, log: Signpost.logger, name: code.name)
  }

  static func intervalStart(_ code: Interval, id: OSSignpostID = .exclusive)
  {
    switch code {
      case .generateConnections(let batchStart),
           .generateLines(let batchStart):
        os_signpost(.begin, log: Signpost.logger, name: code.name,
                    "batch start: %d", batchStart)
      default:
        os_signpost(.begin, log: Signpost.logger, name: code.name)
    }
  }

  static func intervalEnd(_ code: Interval, id: OSSignpostID = .exclusive)
  {
    os_signpost(.end, log: Signpost.logger, name: code.name)
  }

  static func intervalStart(_ code: Interval, object: AnyObject)
  {
    intervalStart(code, id: OSSignpostID(log: Signpost.logger, object: object))
  }

  static func intervalEnd(_ code: Interval, object: AnyObject)
  {
    intervalEnd(code, id: OSSignpostID(log: Signpost.logger, object: object))
  }

  static func interval<T>(_ code: Interval,
                          call: () throws -> T) rethrows -> T
  {
    let id = OSSignpostID(log: .default)
    
    intervalStart(code, id: id)
    defer {
      intervalEnd(code, id: id)
    }
    return try call()
  }
}
