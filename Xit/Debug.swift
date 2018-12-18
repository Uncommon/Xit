import Foundation

enum Signpost: UInt32
{
  case historyWalking = 0
  case connectCommits = 1
  case generateConnections = 2
  case generateLines = 3
  case sidebarReload = 4
  case windowControllerLoad = 5
  case postIndexChanged = 6
  case loadIndex = 7
  case loadWorkspace = 8
  case detectIndexChanged = 9
  case loadTags = 10
}

func signpost(_ code: Signpost,
              _ arg1: UInt = 0, _ arg2: UInt = 0,
              _ arg3: UInt = 0, _ arg4: UInt = 0)
{
  kdebug_signpost(code.rawValue, arg1, arg2, arg3, arg4)
}

func signpostStart(_ code: Signpost,
                   _ arg1: UInt = 0, _ arg2: UInt = 0,
                   _ arg3: UInt = 0, _ arg4: UInt = 0)
{
  kdebug_signpost_start(code.rawValue, arg1, arg2, arg3, arg4)
}

func signpostEnd(_ code: Signpost,
                 _ arg1: UInt = 0, _ arg2: UInt = 0,
                 _ arg3: UInt = 0, _ arg4: UInt = 0)
{
  kdebug_signpost_end(code.rawValue, arg1, arg2, arg3, arg4)
}

func withSignpost<T>(_ code: Signpost,
                     _ arg1: UInt = 0, _ arg2: UInt = 0,
                     _ arg3: UInt = 0, _ arg4: UInt = 0,
                     call: () throws -> T) rethrows -> T
{
  kdebug_signpost_start(code.rawValue, arg1, arg2, arg3, arg4)
  defer {
    kdebug_signpost_end(code.rawValue, arg1, arg2, arg3, arg4)
  }
  return try call()
}
