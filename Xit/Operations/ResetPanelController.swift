import Cocoa

class ResetPanelController: SheetController
{
  enum ResetStatus
  {
    /// No changes to worry about
    case clean
    /// There are changes but they will not be lost
    case safe
    /// There are changes but they will be lost
    case dataLoss
    
    var uiDescription: UIString
    {
      switch self {
        case .clean:
          return .resetStatusClean
        case .safe:
          return .resetStatusSafe
        case .dataLoss:
          return .resetStatusDataLoss
      }
    }
    
    var imageName: NSImage.Name
    {
      switch self {
        case .clean, .safe:
          return NSImage.statusAvailableName
        case .dataLoss:
          return NSImage.statusUnavailableName
      }
    }
  }
  
  enum ModeSegment
  {
    static let soft = 0
    static let mixed = 1
    static let hard = 2
  }
  
  @IBOutlet var modeControl: NSSegmentedControl!
  @IBOutlet var descriptionLabel: NSTextField!
  @IBOutlet var statusLabel: NSTextField!
  @IBOutlet var statusImage: NSImageView!
  
  var repository: FileStatusDetection!
  let observers = ObserverCollection()
  
  private var isWorkspaceClean: Bool
  {
    return repository.unstagedChanges(showIgnored: false).isEmpty
  }
  
  private var isStageClean: Bool
  {
    return repository.stagedChanges().isEmpty
  }
  
  public var mode: ResetMode
  {
    get
    {
      return mode(forSegment: modeControl.selectedSegment)
    }
    set
    {
      let segment: Int
      
      switch newValue {
        case .soft:  segment = ModeSegment.soft
        case .mixed: segment = ModeSegment.mixed
        case .hard:  segment = ModeSegment.hard
      }
      modeControl.setSelected(true, forSegment: segment)
      updateStatusText()
      descriptionLabel.uiStringValue = newValue.uiDescription
    }
  }
  
  /// Starts observing the given repository for status changes and updates
  /// informational text accordingly.
  public func observe(repository: FileStatusDetection)
  {
    let updateBlock: (Notification) -> Void = {
      [weak self] _ in
      self?.updateStatusText()
    }
    
    self.repository = repository
    
    observers.addObserver(forName: .XTRepositoryIndexChanged,
                          object: repository, queue: nil, using: updateBlock)
    observers.addObserver(forName: .XTRepositoryWorkspaceChanged,
                          object: repository, queue: nil, using: updateBlock)
    updateStatusText()
  }

  private func updateStatusText()
  {
    let status: ResetStatus
    
    switch mode {
      case .soft:
        status = isWorkspaceClean && isStageClean ? .clean : .safe
      case .mixed:
        switch (isWorkspaceClean, isStageClean) {
          case (true, true):
            status = .clean
          case (false, true):
            status = .safe
          case (false, false), (true, false):
            status = .dataLoss
        }
      case .hard:
        status = isWorkspaceClean && isStageClean ? .clean : .dataLoss
    }
    setStatus(status)
  }

  private func setStatus(_ status: ResetStatus)
  {
    statusImage.image = NSImage(named: status.imageName)
    statusLabel.uiStringValue = status.uiDescription
  }
  
  private func mode(forSegment segment: Int) -> ResetMode
  {
    switch segment {
      case ModeSegment.soft:
        return .soft
      case ModeSegment.mixed:
        return .mixed
      case ModeSegment.hard:
        return .hard
      default:
        return .soft
    }
  }
  
  @IBAction
  private func modeSelected(_ sender: NSSegmentedControl)
  {
    mode = mode(forSegment: sender.selectedSegment)
  }
}

extension ResetMode
{
  var uiDescription: UIString
  {
    switch self {
      case .soft:
        return .resetSoftDescription
      case .mixed:
        return .resetMixedDescription
      case .hard:
        return .resetHardDescription
    }
  }
}
