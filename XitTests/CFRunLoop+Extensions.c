#include <CoreFoundation/CoreFoundation.h>

// NSRunLoop has runUntilDate:, but there is no way to stop it early.
// CFRunLoop can be stopped, but has no buil-in timeout.
// This function returns false if the timeout was triggered.
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
