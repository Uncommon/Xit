import Foundation

public enum SubmoduleIgnore: Int32, Sendable
{
  case unspecified = 0
  case none = 1
  case untracked = 2
  case dirty = 3
  case all = 4
}

public enum SubmoduleUpdate: UInt32, Sendable
{
  case `default` = 0
  case checkout = 1
  case rebase = 2
  case merge = 3
  case none = 4
}

public enum SubmoduleRecurse: UInt32, Sendable
{
  case no = 0
  case yes = 1
  case onDemand = 2
}
