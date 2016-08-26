import Cocoa

public class XTActivityViewController: NSTitlebarAccessoryViewController {

  var activityCount: UInt = 0
  
  @IBOutlet var spinner: NSProgressIndicator!
  
  public override func awakeFromNib()
  {
    layoutAttribute = .Right
    spinner.hidden = true
  }
  
  func forceMainThread(block: dispatch_block_t)
  {
    let mainQueue = dispatch_get_main_queue()
    
    if NSThread.isMainThread() {
      block()
    }
    else {
      dispatch_sync(mainQueue, block)
    }
  }
  
  func activityStarted()
  {
    forceMainThread() {
      self.activityCount += 1
      self.spinner.hidden = false
      self.spinner.startAnimation(self)
    }
  }
  
  func activityEnded()
  {
    forceMainThread() {
      guard self.activityCount > 0
      else { return }
      
      self.activityCount -= 1
      if self.activityCount == 0 {
        self.spinner.stopAnimation(self)
        self.spinner.hidden = true
      }
    }
  }
}
