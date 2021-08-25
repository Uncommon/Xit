import Cocoa

final class SidebarCheckedRowView: NSTableRowView
{
  private weak var imageView: NSImageView?
  private let image: NSImage
  private let imageToolTip: UIString?
  
  init(image: NSImage = .xtCurrentBranch,
       toolTip: UIString? = nil)
  {
    self.image = image
    self.imageToolTip = toolTip
    
    super.init(frame: NSRect.zero)
  }
  
  required init?(coder: NSCoder)
  {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidMoveToSuperview()
  {
    super.viewDidMoveToSuperview()
    
    guard self.imageView == nil,
          let columnView = view(atColumn: 0)
    else { return }
    
    let imageView = NSImageView(frame: NSRect(origin: NSPoint.zero,
                                              size: image.size))
    
    self.imageView = imageView
    imageView.translatesAutoresizingMaskIntoConstraints = false
    imageView.toolTip = imageToolTip?.rawValue
    addSubview(imageView)
    
    let hSpacer = NSLayoutConstraint(item: imageView, attribute: .trailing,
                                     relatedBy: .equal,
                                     toItem: columnView, attribute: .leading,
                                     multiplier: 1.0, constant: 0.0)
    let vertical = NSLayoutConstraint(item: imageView, attribute: .centerY,
                                      relatedBy: .equal,
                                      toItem: columnView, attribute: .centerY,
                                      multiplier: 1.0, constant: 0)
 
    imageView.image = image
    addConstraints([hSpacer, vertical])
  }
}
