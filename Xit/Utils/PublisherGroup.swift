import Foundation
import Combine

/// A set of publishers, identified by `TypeEnum`, that all send the same type
/// via `PassthroughSubject`.
class PublisherGroup<Value, Error, TypeEnum>
  where Error: Swift.Error, TypeEnum: CaseIterable & Hashable
{
  typealias Subject = PassthroughSubject<Value, Error>

  private let subjects: [TypeEnum: Subject] =
    TypeEnum.allCases.reduce(into: [:]) { $0[$1] = Subject() }

  func subject(_ type: TypeEnum) -> Subject
  { subjects[type]! }

  func publisher(_ type: TypeEnum) -> AnyPublisher<Value, Error>
  { subjects[type]!.eraseToAnyPublisher() }

  func send(_ type: TypeEnum, _ value: Value)
  { subjects[type]!.send(value) }

  subscript(_ type: TypeEnum) -> AnyPublisher<Value, Error>
  { publisher(type) }
}

extension PublisherGroup where Value == Void
{
  func send(_ type: TypeEnum)
  { subjects[type]!.send() }
}
