import Foundation
import SwiftUI
import XitGit


/// Property wrapper that binds to a `Config` value.
@propertyWrapper
struct ConfigValue<T>: DynamicProperty where T: ConfigValueType
{
  let key: String
  let config: any Config
  let `default`: T

  var wrappedValue: T
  {
    get { config.value(for: key) as T? ?? `default` }
    set { config.set(value: newValue, for: key) }
  }

  var projectedValue: Binding<T>
  {
    .init(get: { wrappedValue },
          // re-implement setter because "self is immutable"
          set: { config.set(value: $0, for: key) })
  }
}
