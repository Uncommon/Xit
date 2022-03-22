import Foundation
import os

enum Signpost
{
  static let logger = OSLog(subsystem: "com.uncommonplace.xit",
                            category: .pointsOfInterest)

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
    case refreshPullRequests
    case refreshBuildStatus
    case teamCityQuery
    case teamCityProcess
    case buildStatusUpdate(String)
    
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
        case .refreshPullRequests: return "refresh pull requests"
        case .refreshBuildStatus: return "refresh build status"
        case .teamCityQuery: return "query TeamCity"
        case .teamCityProcess: return "process TeamCity response"
        case .buildStatusUpdate: return "build status update"
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
        os_signpost(.begin, log: Signpost.logger, name: code.name, signpostID: id,
                    "batch start: %d", batchStart)
      case .buildStatusUpdate(let buildType):
        os_signpost(.begin, log: Signpost.logger, name: code.name, signpostID: id,
                    "build type: %s", buildType)
      default:
        os_signpost(.begin, log: Signpost.logger, name: code.name, signpostID: id)
    }
  }

  static func intervalEnd(_ code: Interval, id: OSSignpostID = .exclusive)
  {
    os_signpost(.end, log: Signpost.logger, name: code.name, signpostID: id)
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
    let id = OSSignpostID(log: Signpost.logger)
    
    intervalStart(code, id: id)
    defer {
      intervalEnd(code, id: id)
    }
    return try call()
  }

  static func interval<T>(_ code: Interval,
                          call: () async throws -> T) async rethrows -> T
  {
    let id = OSSignpostID(log: Signpost.logger)

    intervalStart(code, id: id)
    defer {
      intervalEnd(code, id: id)
    }
    return try await call()
  }
}
