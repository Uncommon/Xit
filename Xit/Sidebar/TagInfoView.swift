import SwiftUI

/// Tag details displayed in the sidebsar popover
struct TagInfoView: View
{
  let name: String
  let email: String
  let when: Date
  let message: String
  let formatter = DateFormatter()

  var body: some View
  {
    VStack(alignment: .leading) {
      HStack(alignment: .firstTextBaseline) {
        Image(systemName: "tag.fill")
        if #available(macOS 12.0, *) {
          Text(name).fontWeight(.bold).textSelection(.enabled)
        }
        else {
          Text(name).fontWeight(.bold)
        }
        if !email.isEmpty {
          if #available(macOS 12.0, *) {
            Text("<\(email)>").textSelection(.enabled)
          }
          else {
            Text("<\(email)>")
          }
        }
      }
      HStack(alignment: .firstTextBaseline) {
        Image(systemName: "calendar")
        Text(formatter.string(from: when))
      }.padding(.top, 1)
      if !message.isEmpty {
        Text(message)
          .padding(.top, 8)
          .lineLimit(4)
      }
    }.padding().frame(minWidth: 400, maxWidth: 400, alignment: .leading)
  }

  init(tag: any Tag)
  {
    if let signature = tag.signature {
      self.name = signature.name ?? "-"
      self.email = signature.email ?? ""
      self.when = signature.when
    }
    else {
      self.name = "-"
      self.email = ""
      self.when = .distantPast
    }
    self.message = tag.message ?? ""

    formatter.dateStyle  = .short
    formatter.timeStyle = .short
  }
}

struct TagInfoView_Previews: PreviewProvider
{
  struct TestTag: Tag
  {
    let name: String
    let signature: Signature?
    let targetOID: StringOID?
    let commit: StringCommit?
    let message: String?
    let type: TagType
    let isSigned: Bool
  }

  static let noMessageTag = TestTag(
      name: "someTag",
      signature: .init(name: "This Guy",
                       email: "thisguy@example.com",
                       when: .init(timeIntervalSinceReferenceDate: 0)),
      targetOID: nil, commit: nil,
      message: "", type: .annotated, isSigned: false)
  static let wrappedMessageTag = TestTag(
      name: "someTag",
      signature: .init(name: "Other Odd Guy",
                       email: "otherguy@exampleexample.com",
                       when: .init(timeIntervalSinceReferenceDate: 0)),
      targetOID: nil,
      commit: nil,
      message: "Long enough text to hopefully wrap around to two lines of text",
      type: .annotated, isSigned: false)
  static let truncatedMessageTag = TestTag(
      name: "someTag",
      signature: .init(name: "Other Guy",
                       email: "otherguy@example.com",
                       when: .init(timeIntervalSinceReferenceDate: 0)),
      targetOID: nil,
      commit: nil,
      message: """
        Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod \
        tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim \
        veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea \
        commodo consequat. Duis aute irure dolor in reprehenderit in voluptate \
        velit esse cillum dolore eu fugiat nulla pariatur.
        """,
      type: .annotated, isSigned: false)

  static var previews: some View
  {
    Group {
      TagInfoView(tag: noMessageTag)
      TagInfoView(tag: wrappedMessageTag)
      TagInfoView(tag: truncatedMessageTag)
    }
  }
}
