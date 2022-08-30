import SwiftUI
import AppKit

struct SearchField: NSViewRepresentable
{
  init(_ searchString: Binding<String>,
       prompt: String? = nil)
  {
    self._searchString = searchString
    self.prompt = prompt
  }

  @Binding var searchString: String

  let prompt: String?
  var onStart: (() -> Void)?
  var onEnd: (() -> Void)?
  var searchAction: ((String) -> Void)?

  func makeNSView(context: Context) -> NSSearchField
  {
    let field = NSSearchField()

    field.delegate = context.coordinator
    field.target = context.coordinator
    field.action = #selector(Coordinator.searchAction(_:))
    field.placeholderString = prompt
    field.sendsSearchStringImmediately = false
    field.sendsWholeSearchString = true
    return field
  }

  func updateNSView(_ nsView: NSSearchField, context: Context)
  {
    nsView.stringValue = searchString
  }

  func makeCoordinator() -> Coordinator
  {
    Coordinator(owner: self)
  }

  /// Sets a callback for when the user begins entering text.
  func onStartSearching(_ start: @escaping () -> Void) -> SearchField
  {
    var field = self
    field.onStart = start
    return field
  }

  /// Sets a callback for when the field becomes empty.
  func onEndSearching(_ end: @escaping () -> Void) -> SearchField
  {
    var field = self
    field.onEnd = end
    return field
  }

  func onSearch(_ action: @escaping (String) -> Void) -> SearchField
  {
    var field = self
    field.searchAction = action
    return field
  }

  class Coordinator: NSObject, NSSearchFieldDelegate
  {
    var owner: SearchField

    init(owner: SearchField)
    {
      self.owner = owner
    }

    func controlTextDidChange(_ obj: Notification)
    {
      guard let searchField = obj.object as? NSSearchField
      else { return }

      owner.searchString = searchField.stringValue
    }

    func searchFieldDidStartSearching(_ sender: NSSearchField)
    {
      owner.onStart?()
    }

    func searchFieldDidEndSearching(_ sender: NSSearchField)
    {
      owner.onEnd?()
    }

    @objc
    func searchAction(_ sender: NSSearchField)
    {
      owner.searchString = sender.stringValue
      owner.searchAction?(sender.stringValue)
    }
  }
}

struct SearchField_Previews: PreviewProvider
{
  @State static var searchText = "beginning"
  @State static var toggle = false

  static var previews: some View
  {
    VStack(alignment: .leading) {
      SearchField($searchText, prompt: "Find")
        .onSearch { _ in
          toggle.toggle()
        }
      TextField(text: $searchText, label: { EmptyView() })
      Text("Entered: \(searchText)").disabled(toggle)
    }.padding()
  }
}
