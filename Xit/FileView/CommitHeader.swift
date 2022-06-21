import SwiftUI

extension Font
{
  static var code: Font
  {
    .init(NSFont(name: UserDefaults.standard.fontName,
                 size: CGFloat(UserDefaults.standard.fontSize))
          ?? .monospacedSystemFont(ofSize: 11, weight: .regular))
  }
}

class CommitHeaderHostingView: NSHostingView<CommitHeader>
{
  var repository: CommitStorage?
  var selectParent: ((any OID) -> Void)?
  
  var commit: (any Commit)?
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
  let commit: (any Commit)?
  let messageLookup: (any OID) -> String
  let selectParent: (any OID) -> Void
  
  enum Measurement
  {
    static let margin: CGFloat = 12
    static let divider: CGFloat = 8
  }
  
  static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
  }()
  
  var body: some View {
    if let commit = commit {
      ScrollView {
        VStack(alignment: .leading, spacing: Measurement.divider) {
          VStack(spacing: 6) {
            if let author = commit.authorSig {
              SignatureRow(icon: Image(systemName: "pencil.circle.fill"),
                           help: "Author",
                           signature: author)
            }
            if let committer = commit.committerSig,
               committer != commit.authorSig {
              SignatureRow(icon: Image(systemName: "smallcircle.fill.circle.fill"),
                           help: "Committer",
                           signature: committer)
            }
            HStack(alignment: .firstTextBaseline) {
              VStack(alignment: .leading) {
                ForEach(commit.parentOIDs, id: \.sha) { oid in
                  HStack {
                    CommitHeaderLabel(text: "Parent:")
                    Text(messageLookup(oid))
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
                        selectParent(oid)
                      }
                      .accessibility(identifier: "parent")
                  }
                }
              }
                .accessibilityElement(children: .contain)
                .accessibility(identifier: "parents")
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
              }
                .buttonStyle(LinkButtonStyle())
                .accessibility(identifier: "sha")
            }
          }
            .padding([.top, .horizontal], Measurement.margin)
            .padding([.bottom], Measurement.divider)
            .background(Color(.windowBackgroundColor))
          Text(commit.message?.trimmingWhitespace ?? "")
            .accessibility(identifier: "message")
            .fixedSize(horizontal: false, vertical: true)
            .font(.code)
            .padding([.bottom, .horizontal], Measurement.margin)
        }
      }
        .background(Color(.textBackgroundColor))
        .accessibilityElement(children: .contain)
        .accessibility(identifier: "commitInfo")
    }
    else {
      Text("No selection").foregroundColor(.secondary).bold()
    }
  }
}

struct SignatureRow: View
{
  let icon: Image
  let help: String
  let signature: Signature
  
  var body: some View {
    HStack {
      icon.foregroundColor(.secondary).help(help)
      if let name = signature.name {
        Text(name).bold()
          .accessibility(identifier: "name")
      }
      if let email = signature.email {
        Text("<\(email)>").bold().foregroundColor(.secondary)
          .accessibility(identifier: "email")
      }
      Spacer()
      Text(signature.when, formatter: CommitHeader.dateFormatter)
        .accessibility(identifier: "date")
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
    let parentOIDs: [any OID] = ["A", "B"]
    let message: String? = "Single line"
    let tree: (any Tree)? = nil
    let id: any OID = "45a608978"

    let authorSig: Signature? = Signature(name: "Author Person",
                                          email: "author@example.com",
                                          when: Date())
    
    let committerSig: Signature? = Signature(name: "Committer Person",
                                             email: "commit@example.com",
                                             when: Date())

    var isSigned: Bool { false }
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
