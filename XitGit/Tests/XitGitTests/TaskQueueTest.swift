import Combine
import XCTest
@testable import XitGit

final class TaskQueueTest: XCTestCase
{
  private func runOnMainThread<T>(_ block: @escaping () throws -> T) throws -> T
  {
    if Thread.isMainThread {
      return try block()
    }
    else {
      return try DispatchQueue.main.sync(execute: block)
    }
  }

  func testTaskQueueBusyPublisherTransitionsTrueFalse()
  {
    let queue = TaskQueue(id: "TaskQueueTest.busyPublisher")
    let transitioned = expectation(description: "busy transitions")
    let stateQueue = DispatchQueue(label: "TaskQueueTest.state")
    var states: [Bool] = []
    var fulfilled = false

    let sink = queue.busyPublisher.sink {
      state in
      stateQueue.sync {
        states.append(state)
        guard !fulfilled else { return }

        if let firstBusy = states.firstIndex(of: true),
           let lastIdle = states.lastIndex(of: false),
           lastIdle > firstBusy {
          fulfilled = true
          transitioned.fulfill()
        }
      }
    }

    queue.executeAsync {
      try? await Task.sleep(nanoseconds: 30_000_000)
    }

    wait(for: [transitioned], timeout: 2.0)
    queue.wait()
    sink.cancel()

    let captured = stateQueue.sync { states }
    let firstBusy = captured.firstIndex(of: true)
    let lastIdle = captured.lastIndex(of: false)

    XCTAssertNotNil(firstBusy)
    XCTAssertNotNil(lastIdle)
    if let firstBusy, let lastIdle {
      XCTAssertGreaterThan(lastIdle, firstBusy)
    }
  }

  func testTaskQueueSyncOffMainThreadThrowsAfterShutdown()
  {
    let queue = TaskQueue(id: "TaskQueueTest.syncOffMainThread")

    queue.shutDown()

    XCTAssertThrowsError(try runOnMainThread {
      try queue.syncOffMainThread { 1 }
    }) {
      error in
      guard case TaskQueue.Error.queueShutDown = error
      else {
        XCTFail("Unexpected error: \(error)")
        return
      }
    }
  }
}
