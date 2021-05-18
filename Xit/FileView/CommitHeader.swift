import SwiftUI

extension Font
{
  static var code: Font { .init(PreviewsPrefsController.Default.font()) }
}

class CommitHeaderHostingView: NSHostingView<CommitHeader>
{
  var repository: CommitStorage?
  var selectParent: ((OID) -> Void)?
  
  var commit: Commit?
  {
    get { rootView.commit }
    set {
      guard let select = selectParent
      else { return }
      
      rootView = CommitHeader(
          commit: newValue,
          messageLookup: {
            self.repository?.commit(forOID: $0)?.messageSummary ?? ""
          },
          selectParent: select)
    }
  }
}

struct CommitHeader: View
{
  let commit: Commit?
  let messageLookup: (OID) -> String
  let selectParent: (OID) -> Void
  
  static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
  }()
  
  var body: some View {
    if let commit = commit {
      ScrollView {
      VStack(alignment: .leading, spacing: 4) {
        VStack(spacing: 6) {
          if let author = commit.authorSig {
            SignatureRow(icon: Image(systemName: "pencil.circle.fill"),
                         signature: author)
          }
          if let committer = commit.committerSig,
             committer != commit.authorSig {
            SignatureRow(icon: Image(systemName: "smallcircle.fill.circle.fill"),
                         signature: committer)
          }
          HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading) {
              ForEach(0..<commit.parentOIDs.count) { index in
                HStack {
                  CommitHeaderLabel(text: "Parent:")
                  Text(messageLookup(commit.parentOIDs[index]))
                    .foregroundColor(.blue)
                    .onHover { isInside in
                      if isInside {
                        NSCursor.pointingHand.push()
                      }
                      else {
                        NSCursor.pop()
                      }
                    }
                    .onTapGesture {
                      selectParent(commit.parentOIDs[index])
                    }
                }
              }
            }
            Spacer()
            CommitHeaderLabel(text: "SHA:")
            Button {
              let pasteboard = NSPasteboard.general
              pasteboard.clearContents()
              pasteboard.setString(commit.sha, forType: .string)
            } label: {
              Text(commit.sha.firstSix())
              Image(systemName: "doc.on.clipboard")
                .imageScale(.small)
                .foregroundColor(.secondary)
            }.buttonStyle(LinkButtonStyle())
          }
        }
          .padding([.top, .horizontal])
          .padding([.bottom], 8)
          .background(Color(.windowBackgroundColor))
        Text(commit.message ?? "")
          .fixedSize(horizontal: false, vertical: true)
          .font(.code)
          .padding([.bottom, .horizontal])
      }
      }
      .background(Color(.textBackgroundColor))
    }
    else {
      Text("No selection").foregroundColor(.secondary).bold()
    }
  }
}

struct SignatureRow: View
{
  let icon: Image
  let signature: Signature
  
  var body: some View {
    HStack {
      icon.foregroundColor(.secondary)
      if let name = signature.name {
        Text(name).bold()
      }
      if let email = signature.email {
        Text("<\(email)>").bold().foregroundColor(.secondary)
      }
      Spacer()
      Text(signature.when, formatter: CommitHeader.dateFormatter)
    }
  }
}

struct CommitHeaderLabel: View
{
  let text: String
  
  var body: some View {
    Text(text).font(.body).bold().foregroundColor(.gray)
  }
}

struct CommitHeader_Previews: PreviewProvider
{
  struct PreviewCommit: Commit
  {
    let parentOIDs: [OID] = ["A", "B"]
    let message: String? = "Single line"
    let tree: Tree? = nil
    let oid: OID = "45a608978"

    let authorSig: Signature? = Signature(name: "Author Person",
                                          email: "author@example.com",
                                          when: Date())
    
    let committerSig: Signature? = Signature(name: "Committer Person",
                                             email: "commit@example.com",
                                             when: Date())
  }
  
  static var parents: [String: String] = ["A": "First parent",
                                          "B": "Second parent"]
  
  static var previews: some View {
    CommitHeader(commit: PreviewCommit(),
                 messageLookup: { parents[$0.sha]! },
                 selectParent: { _ in })
    CommitHeader(commit: nil,
                 messageLookup: { _ in "" },
                 selectParent: { _ in })
      .frame(width: 300, height: 200)
  }
}

extension String: OID
{
  public var sha: String { self }
  public var isZero: Bool { self == "00000000000000000000" }
}
