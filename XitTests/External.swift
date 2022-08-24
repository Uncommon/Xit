import Foundation

/// Returns the content of a file outside the project folder, if found.
///
/// Used for tests that rely on sensitive data such as passwords that should
/// not be checked in to the public repository.
func externalFileContent(_ name: String) -> String?
{
  let url = URL(fileURLWithPath: #file)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent(name)
  return try? String(contentsOf: url)
}
