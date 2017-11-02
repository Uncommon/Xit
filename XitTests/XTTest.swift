import Foundation

extension XTTest
{
  func makeTiffFile(_ name: String) throws
  {
    let tiffURL = repository.fileURL(name)
    
    try NSImage(named: .actionTemplate)?.tiffRepresentation?.write(to: tiffURL)
  }
}
