import Foundation
import XitGit
import Clibgit2 // Need Clibgit2 module types visibly to cast to them? No, XitGit re-exports? No.
// But we need to reference Clibgit2.git_oid.
// If XitGit doesn't export strict Clibgit2 dependency, we might not see it.
// XitGit imports Clibgit2. But `public struct GitOID` uses `git_oid` internally.
// `init(oidPtr: UnsafePointer<git_oid>)` uses `git_oid` in signature.
// So `git_oid` (Clibgit2) must be visible if `GitOID` is public?
// Yes.

extension XitGit.GitOID
{
  // Initialize from bridging header git_oid
  init(bridging: git_oid)
  {
    var local = bridging
    // bridging is __C.git_oid (20 bytes)
    // We construct distinct GitOID (wrapping Clibgit2.git_oid, 20 bytes)
    // We can just unsafeBitCast directly if layouts match.
    // Or simpler: use OID string roundtrip if performance allows (slow).
    // Or pointer cast.
    
    // We can't easily access Clibgit2.git_oid type here if not imported.
    // But we can initiate GitOID with the raw bytes?
    
    // Hack: construct via pointer rebound.
    // We need to trick the compiler that UnsafePointer<__C.git_oid> is UnsafePointer<Clibgit2.git_oid>
    // But we can't name Clibgit2.git_oid easily if not imported.
    // However, init(oidPtr:) takes UnsafePointer<XitGit.Clibgit2.git_oid>
    
    // So we can assume the argument type of init(oidPtr:) IS the target type.
    
    self = withUnsafePointer(to: &local) { ptr in
        let rawPtr = UnsafeRawPointer(ptr)
        // We need to call init(oidPtr: A) where A is UnsafePointer<Clibgit2.git_oid>
        // We can cheat by using unsafeBitCast on the function/pointer? No.
        
        // Let's rely on unsafeBitCast of the STRUCT itself which we know has just one field of 20 bytes.
        return unsafeBitCast(local, to: XitGit.GitOID.self)
    }
  }

  var bridgingOID: git_oid
  {
      return unsafeBitCast(self, to: git_oid.self)
  }
}
