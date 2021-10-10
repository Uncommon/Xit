import Foundation

/// Simple pthread mutex wrapper
public class Mutex
{
  private var mutex: UnsafeMutablePointer<pthread_mutex_t>
  
  init()
  {
    var attr = pthread_mutexattr_t()
    
    pthread_mutexattr_init(&attr)
    pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE)
    
    let mutexPtr = UnsafeMutablePointer<pthread_mutex_t>.allocate(capacity: 1)
    
    pthread_mutex_init(mutexPtr, &attr)
    self.mutex = mutexPtr
  }
  
  deinit
  {
    pthread_mutex_destroy(mutex)
    mutex.deallocate()
  }
  
  public func lock()
  {
    pthread_mutex_lock(mutex)
  }
  
  public func unlock()
  {
    pthread_mutex_unlock(mutex)
  }
  
  public func withLock<T>(_ callback: () throws -> T) rethrows -> T
  {
    lock()
    defer { unlock() }
    return try callback()
  }
}
