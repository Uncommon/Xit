#include "XTQueueUtils.h"
#include <CoreFoundation/CoreFoundation.h>

void WaitForQueue(dispatch_queue_t queue)
{
  // Some queued tasks may need to also perform tasks on the main thread, so
  // simply waiting on the queue could cause a deadlock.
  const CFRunLoopRef loop = CFRunLoopGetCurrent();
  __block bool keepLooping = true;

  // Loop because something else might quit the run loop.
  do {
    CFRunLoopPerformBlock(loop, kCFRunLoopCommonModes, ^{
      dispatch_async(queue, ^{
        CFRunLoopStop(loop);
        keepLooping = false;
      });
    });
    CFRunLoopRun();
  } while (keepLooping);
}
