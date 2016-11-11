import Cocoa

class SidebarCheckedRowView: NSTableRowView
{
  weak var imageView: NSImageView? = nil

  override func viewDidMoveToSuperview()
  {
    super.viewDidMoveToSuperview()
    
    guard self.imageView == nil,
          let columnView = view(atColumn: 0)
    else { return }
    
    let check = #imageLiteral(resourceName: NSImageNameMenuOnStateTemplate)
    let imageView = NSImageView(frame: NSRect(origin: NSZeroPoint,
                                              size: check.size))
    
    self.imageView = imageView
    imageView.translatesAutoresizingMaskIntoConstraints = false
    addSubview(imageView)
    
    let hSpacer = NSLayoutConstraint(item: imageView, attribute: .trailing,
                                     relatedBy: .equal,
                                     toItem: columnView, attribute: .leading,
                                     multiplier: 1.0, constant: 0.0)
    let vertical = NSLayoutConstraint(item: imageView, attribute: .centerY,
                                      relatedBy: .equal,
                                      toItem: columnView, attribute: .centerY,
                                      multiplier: 1.0, constant: 0)
 
    imageView.image = check
    self.addConstraints([hSpacer, vertical])
  }
}
