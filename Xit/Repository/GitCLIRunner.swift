import Foundation

let XTErrorDomainGit = "git"
let XTErrorOutputKey = "output"
let XTErrorArgsKey = "args"

/// Manages running the Git command line tool
struct GitCLIRunner
{
  let gitPath: String
  let repoPath: String
  
  /// Executes the Git command line tool with the given command and input data
  /// - Parameter inputData: String data for input, such as file contents
  /// - Parameter args: Command to be passed to Git
  func run(inputString: String, args: [String]) throws -> Data
  {
    return try run(inputData: inputString.data(using: .utf8), args: args)
  }
  
  /// Executes the Git command line tool with the given command and input data
  /// - Parameter inputData: Data for input, such as file contents
  /// - Parameter args: Command to be passed to Git
  func run(inputData: Data? = nil, args: [String]) throws -> Data
  {
    NSLog("*** command = git \(args.joined(separator: " "))")
    
    let task = Process()
    
    task.currentDirectoryPath = repoPath
    task.launchPath = gitPath
    task.arguments = args
    
    // Large files have to be chunked or else FileHandle.write() hangs
    let chunkSize = 10*1024

    if let data = inputData {
      let stdInPipe = Pipe()
      
      if data.count <= chunkSize {
        stdInPipe.fileHandleForWriting.write(data)
        stdInPipe.fileHandleForWriting.closeFile()
      }
      task.standardInput = stdInPipe
    }
    
    let pipe = Pipe()
    let errorPipe = Pipe()
    
    task.standardOutput = pipe
    task.standardError = errorPipe
    try task.throwingLaunch()
    
    if let data = inputData,
       data.count > chunkSize,
       let handle = (task.standardInput as? Pipe)?.fileHandleForWriting {
      for chunkIndex in 0...(data.count/chunkSize) {
        let chunkStart = chunkIndex * chunkSize
        let chunkEnd = min(chunkStart + chunkSize, data.count)
        let subData = data.subdata(in: chunkStart..<chunkEnd)
        
        handle.write(subData)
      }
      handle.closeFile()
    }
    
    let output = pipe.fileHandleForReading.readDataToEndOfFile()
    
    task.waitUntilExit()
    
    guard task.terminationStatus == 0
    else {
      let string = String(data: output, encoding: .utf8) ?? "-"
      let errorOutput = errorPipe.fileHandleForReading.readDataToEndOfFile()
      let errorString = String(data: errorOutput, encoding: .utf8) ?? "-"
      
      NSLog("**** output = \(string)")
      NSLog("**** error = \(errorString)")
      throw NSError(domain: XTErrorDomainGit, code: Int(task.terminationStatus),
                    userInfo: [XTErrorOutputKey: string,
                               XTErrorArgsKey: args.joined(separator: " ")])
    }
    
    return output
  }
}
