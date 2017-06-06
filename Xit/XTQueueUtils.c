#include "XTQueueUtils.h"
#include <CoreFoundation/CoreFoundation.h>
#include <pthread.h>

void WaitForQueue(dispatch_queue_t queue)
{
  dispatch_semaphore_t semaphore = dispatch_semaphore_create(1);
  
  dispatch_async(queue, ^{
    dispatch_semaphore_signal(semaphore);
  });
  dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
}
