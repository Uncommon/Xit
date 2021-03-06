import Foundation

extension NSObject
{
  func changingValue(forKey key: String, block: () -> Void)
  {
    willChangeValue(forKey: key)
    block()
    didChangeValue(forKey: key)
  }
}

extension NSApplication
{
  var currentEventIsDelete: Bool
  {
    switch currentEvent?.specialKey {
      case NSEvent.SpecialKey.delete,
           NSEvent.SpecialKey.backspace,
           NSEvent.SpecialKey.deleteCharacter,
           NSEvent.SpecialKey.deleteForward:
        return true
      default:
        return false
    }
  }
}

extension NSColor
{
  var invertingBrightness: NSColor
  {
    NSColor(deviceHue: hueComponent,
            saturation: saturationComponent,
            brightness: 1.0 - brightnessComponent,
            alpha: alphaComponent)
  }

  var cssHSL: String
  {
    let converted = usingColorSpace(.deviceRGB)!
    let hue = converted.hueComponent
    let sat = converted.saturationComponent
    let brightness = converted.brightnessComponent
    
    return "hsl(\(hue*360.0), \(sat*100.0)%, \(brightness*100.0)%)"
  }
  
  var cssRGB: String
  {
    let converted = usingColorSpace(.deviceRGB)!
    let red = converted.redComponent
    let green = converted.greenComponent
    let blue = converted.blueComponent
    
    return "rgb(\(Int(red*255)), \(Int(green*255)), \(Int(blue*255)))"
  }
  
  func withHue(_ hue: CGFloat) -> NSColor
  {
    guard let converted = usingColorSpace(.deviceRGB)
    else { return self }

    return NSColor(deviceHue: hue,
                   saturation: converted.saturationComponent,
                   brightness: converted.brightnessComponent,
                   alpha: converted.alphaComponent)
  }
}

extension NSError
{
  var gitError: git_error_code
  { git_error_code(Int32(code)) }
  
  convenience init(osStatus: OSStatus)
  {
    self.init(domain: NSOSStatusErrorDomain, code: Int(osStatus), userInfo: nil)
  }
}

extension NSImage
{
  func image(coloredWith color: NSColor) -> NSImage
  {
    guard isTemplate,
          let copiedImage = self.copy() as? NSImage
    else { return self }
    
    copiedImage.withFocus {
      let imageBounds = NSRect(origin: .zero, size: copiedImage.size)

      color.set()
      imageBounds.fill(using: .sourceAtop)
    }
    copiedImage.isTemplate = false
    return copiedImage
  }
  
  func withFocus<T>(callback: () throws -> T) rethrows -> T
  {
    lockFocus()
    defer {
      unlockFocus()
    }
    
    return try callback()
  }
}

extension NSTreeNode
{
  /// Inserts a child node in sorted order based on the given key extractor
  func insert<T>(node: NSTreeNode, sortedBy extractor: (NSTreeNode) -> T?)
    where T: Comparable
  {
    guard let children = self.children,
          let key = extractor(node)
    else {
      mutableChildren.add(node)
      return
    }
    
    for (index, child) in children.enumerated() {
      guard let childKey = extractor(child)
      else { continue }
      
      if childKey > key {
        mutableChildren.insert(node, at: index)
        return
      }
    }
    mutableChildren.add(node)
  }

  func dump(_ level: Int = 0)
  {
    if let myObject = representedObject as? CustomStringConvertible {
      print(String(repeating: "  ", count: level) + myObject.description)
    }
    
    guard let children = self.children
    else { return }
    
    for child in children {
      child.dump(level + 1)
    }
  }
}
