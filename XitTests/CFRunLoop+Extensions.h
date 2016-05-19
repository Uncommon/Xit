#ifndef Xit_CFRunLoop_Extensions_h
#define Xit_CFRunLoop_Extensions_h

/**
 * Runs the run loop with the given timeout.
 * @return False if the timeout expires, otherwise true.
 */
bool CFRunLoopRunWithTimeout(CFTimeInterval timeout);

#endif
