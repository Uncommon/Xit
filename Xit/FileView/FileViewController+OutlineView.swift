import Foundation

// TODO: Move these out
extension FileViewController: NSOutlineViewDelegate
{
  private func displayChange(forChange change: DeltaStatus,
                             otherChange: DeltaStatus) -> DeltaStatus
  {
    return (change == .unmodified) && (otherChange != .unmodified)
           ? .mixed : change
  }

  private func stagingImage(forChange change: DeltaStatus,
                            otherChange: DeltaStatus) -> NSImage?
  {
    let change = displayChange(forChange: change, otherChange: otherChange)
    
    return change.stageImage
  }
}
