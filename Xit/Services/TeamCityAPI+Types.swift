// URL should be Sendable
@preconcurrency import Foundation

extension TeamCityAPI
{
  public struct Build: Sendable
  {
    enum Status: String, Sendable
    {
      case succeeded = "SUCCESS"
      case failed = "FAILURE"
    }
    
    enum State: String, Sendable
    {
      case running
      case finished
    }
    
    enum Attribute: Sendable
    {
      static let id = "id"
      static let buildType = "buildTypeId"
      static let buildNumber = "number"
      static let status = "status"
      static let state = "state"
      static let running = "running"
      static let percentage = "percentageComplete"
      static let branchName = "branchName"
      static let href = "href"
      static let webURL = "webUrl"
    }
    
    let id: Int
    let number: String
    let buildType: String?
    let status: Status?
    let state: State?
    let percentage: Double?
    let running: Bool?
    let url: URL?
    
    init?(element buildElement: XMLElement)
    {
      guard buildElement.name == "build"
      else { return nil }
      
      let attributes = buildElement.attributesDict()
      
      self.id = attributes[Attribute.id].flatMap { Int($0) } ?? 0
      self.number = attributes[Attribute.buildNumber] ?? ""
      self.buildType = attributes[Attribute.buildType]
      self.status = attributes[Attribute.status].flatMap { Status(rawValue: $0) }
      self.state = attributes[Attribute.state].flatMap { State(rawValue: $0) }
      self.percentage = attributes[Attribute.percentage].flatMap { Double($0) }
      self.running = attributes[Attribute.running].map { $0 == "true" }
      self.url = attributes[Attribute.webURL].flatMap { URL(string: $0) }
    }
    
    init?(xml: XMLDocument)
    {
      guard let build = xml.rootElement()
      else { return nil }
      
      self.init(element: build)
    }
  }
}

public struct BuildType
{
  let id: String
  let name: String
  let projectName: String
}

/// A branch specification describes which branches in a VCS are used,
/// and how their names are displayed.
public class BranchSpec
{
  enum Inclusion
  {
    case include
    case exclude
  }

  /// An invididual matching rule in a branch specification.
  struct Rule
  {
    let inclusion: Inclusion
    let regex: NSRegularExpression

    init?(content: String)
    {
      let prefixEndIndex = content.index(content.startIndex,
                                         offsetBy: 2)
      let prefix = String(content[..<prefixEndIndex])

      switch prefix {
        case "+:":
          self.inclusion = .include
        case "-:":
          self.inclusion = .exclude
        default:
          print("Unknown prefix in rule: \(content)")
          return nil
      }

      var substring = String(content[prefixEndIndex...])

      // Parentheses are needed to identify a range to be extracted.
      substring = substring.replacingOccurrences(of: "*", with: "(.+)")
      substring.insert("^", at: substring.startIndex)

      if let regex = try? NSRegularExpression(pattern: substring) {
        self.regex = regex
      }
      else {
        return nil
      }
    }

    func match(branch: String) -> String?
    {
      if branch == regex.pattern.dropFirst() { // skip the "^"
        return branch
      }
      let stringRange = NSRange(location: 0, length: branch.utf8.count)
      guard let match = regex.firstMatch(in: branch, options: .anchored,
                                         range: stringRange)
      else { return nil }

      if match.numberOfRanges >= 2 {
        return (branch as NSString).substring(with: match.range(at: 1))
      }
      return nil
    }
  }

  let rules: [Rule]

  init?(ruleStrings: [String])
  {
    self.rules = ruleStrings.compactMap { Rule(content: $0) }
    if self.rules.isEmpty {
      return nil
    }
  }

  class func defaultSpec() -> BranchSpec
  {
    return BranchSpec(ruleStrings: ["+:refs/heads/*"])!
  }

  /// If the given branch matches the rules, the display name is returned,
  /// otherwise nil.
  func match(branch: String) -> String?
  {
    for rule in rules {
      if let result = rule.match(branch: branch) {
        return rule.inclusion == .include ? result : nil
      }
    }
    return nil
  }
}

