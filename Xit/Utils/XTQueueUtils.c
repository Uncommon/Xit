#include "XTQueueUtils.h"
#include <CoreFoundation/CoreFoundation.h>
#include <pthread.h>

bool AccessBool(pthread_mutex_t *mutex, bool (^block)(void))
{
  bool result;
  
  pthread_mutex_lock(mutex);
  result = block();
  pthread_mutex_unlock(mutex);
  return result;
}

void SetBool(pthread_mutex_t *mutex, bool *value, bool newValue)
{
  pthread_mutex_lock(mutex);
  *value = newValue;
  pthread_mutex_unlock(mutex);
}

void WaitForQueue(dispatch_queue_t queue)
{
  if (queue == NULL)
    return;
  
  __block pthread_mutex_t mutex;
  
  pthread_mutex_init(&mutex, NULL);

  // Some queued tasks may need to also perform tasks on the main thread, so
  // simply waiting on the queue could cause a deadlock.
  const CFRunLoopRef loop = CFRunLoopGetCurrent();
  __block bool keepLooping = true;

  // Loop because something else might quit the run loop.
  do {
    CFRunLoopPerformBlock(loop, kCFRunLoopCommonModes, ^{
      dispatch_async(queue, ^{
        SetBool(&mutex, &keepLooping, false);
        CFRunLoopStop(loop);
      });
    });
    CFRunLoopRun();
  } while (AccessBool(&mutex, ^{ return keepLooping; }));
  pthread_mutex_destroy(&mutex);
}
