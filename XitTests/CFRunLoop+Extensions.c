#include <CoreFoundation/CoreFoundation.h>

// NSRunLoop has runUntilDate:, but there is no way to stop it early.
// CFRunLoop can be stopped, but has no built-in timeout.
/// Runs the run loop until it is stopped or the timeout is reached.
/// @param timeout Amount of time to allow before aborting.
/// @return True if the run loop was stopped, false if it timed out.
bool CFRunLoopRunWithTimeout(CFTimeInterval timeout)
{
  __block bool result = true;
  CFRunLoopRef loop = CFRunLoopGetCurrent();
  CFRunLoopTimerRef timer = CFRunLoopTimerCreateWithHandler(
      kCFAllocatorDefault, CFAbsoluteTimeGetCurrent() + timeout, 0, 0, 0,
      ^(CFRunLoopTimerRef timer) {
        CFRunLoopStop(loop);
        result = false;
      });

  CFRunLoopAddTimer(loop, timer, kCFRunLoopCommonModes);
  CFRunLoopRun();
  CFRunLoopRemoveTimer(loop, timer, kCFRunLoopCommonModes);
  CFRelease(timer);
  return result;
}
