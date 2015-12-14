//
//  ReadWriteLock.swift
//  ReadWriteLock
//
//  Created by John Gallagher on 7/17/14.
//  Copyright © 2014-2015 Big Nerd Ranch. Licensed under MIT.
//

import Dispatch

/// A type that mutually excludes execution of code such that only one unit of
/// code is running at any given time. An implementing type may choose to have
/// readers-writer semantics, such that many readers can read at once, or lock
/// around all reads and writes the same way.
public protocol ReadWriteLock {
    /// Call `body` with a reading lock.
    ///
    /// If the implementing type models a readers-writer lock, this function may
    /// behave differently to `withWriteLock(_:)`.
    ///
    /// - parameter body: A function that reads a value while locked.
    /// - returns: The value returned from the given function.
    func withReadLock<Return>(@noescape body: () throws -> Return) rethrows -> Return

    /// Call `body` with a writing lock.
    ///
    /// If the implementing type models a readers-writer lock, this function may
    /// behave differently to `withReadLock(_:)`.
    ///
    /// - parameter body: A function that writes a value while locked, then returns some value.
    /// - returns: The value returned from the given function.
    func withWriteLock<Return>(@noescape body: () throws -> Return) rethrows -> Return
}

extension ReadWriteLock {
    /// Call `body` with a lock.
    ///
    /// - parameter body: A function that writes a value while locked, then returns some value.
    /// - returns: The value returned from the given function.
    public func withWriteLock<Return>(@noescape body: () throws -> Return) rethrows -> Return {
        return try withReadLock(body)
    }
}

/// A locking construct using a counting semaphore from Grand Central Dispatch.
/// This locking type behaves the same for both read and write locks.
///
/// The semaphore lock performs comparably to a spinlock under little lock
/// contention, and comparably to a platform lock under contention.
public struct DispatchLock: ReadWriteLock {
    private let semaphore = dispatch_semaphore_create(1)

    /// Create a normal instance.
    public init() {}

    /// Call `body` with a lock.
    /// - parameter body: A function that reads a value while locked.
    /// - returns: The value returned from the given function.
    public func withReadLock<Return>(@noescape body: () throws -> Return) rethrows -> Return {
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
        defer {
            dispatch_semaphore_signal(semaphore)
        }
        return try body()
    }
}

/// A spin lock provided by Darwin, the low-level system under iOS and OS X.
///
/// A spin lock polls to check the state of the lock, which is much faster
/// when there isn't contention but rapidly slows down otherwise.
public final class SpinLock: ReadWriteLock {
    private var lock: UnsafeMutablePointer<OSSpinLock>

    /// Allocate a normal spinlock.
    public init() {
        lock = UnsafeMutablePointer.alloc(1)
        lock.initialize(OS_SPINLOCK_INIT)
    }

    deinit {
        lock.destroy()
        lock.dealloc(1)
    }

    /// Call `body` with a lock.
    /// - parameter body: A function that reads a value while locked.
    /// - returns: The value returned from the given function.
    public func withReadLock<Return>(@noescape body: () throws -> Return) rethrows -> Return {
        OSSpinLockLock(lock)
        defer {
            OSSpinLockUnlock(lock)
        }
        return try body()
    }
}

/// A custom spin-lock with readers-writer semantics. The spin lock will poll
/// to check the state of the lock, allowing many readers at the same time.
public final class CASSpinLock: ReadWriteLock {
    private struct Masks {
        static let WRITER_BIT: Int32         = 0x40000000
        static let WRITER_WAITING_BIT: Int32 = 0x20000000
        static let MASK_WRITER_BITS          = WRITER_BIT | WRITER_WAITING_BIT
        static let MASK_READER_BITS          = ~MASK_WRITER_BITS
    }

    private var _state: UnsafeMutablePointer<Int32>

    /// Allocate the spinlock.
    public init() {
        _state = UnsafeMutablePointer.alloc(1)
        _state.initialize(0)
    }

    deinit {
        _state.destroy()
        _state.dealloc(1)
    }

    /// Call `body` with a writing lock.
    ///
    /// The given function is guaranteed to be called exclusively.
    ///
    /// - parameter body: A function that writes a value while locked, then returns some value.
    /// - returns: The value returned from the given function.
    public func withWriteLock<Return>(@noescape body: () throws -> Return) rethrows -> Return {
        // spin until we acquire write lock
        repeat {
            let state = _state.memory

            // if there are no readers and no one holds the write lock, try to grab the write lock immediately
            if (state == 0 || state == Masks.WRITER_WAITING_BIT) &&
                OSAtomicCompareAndSwap32Barrier(state, Masks.WRITER_BIT, _state) {
                    break
            }

            // If we get here, someone is reading or writing. Set the WRITER_WAITING_BIT if
            // it isn't already to block any new readers, then wait a bit before
            // trying again. Ignore CAS failure - we'll just try again next iteration
            if state & Masks.WRITER_WAITING_BIT == 0 {
                OSAtomicCompareAndSwap32Barrier(state, state | Masks.WRITER_WAITING_BIT, _state)
            }
        } while true
        
        defer {
            // unlock
            repeat {
                let state = _state.memory
                
                // clear everything except (possibly) WRITER_WAITING_BIT, which will only be set
                // if another writer is already here and waiting (which will keep out readers)
                if OSAtomicCompareAndSwap32Barrier(state, state & Masks.WRITER_WAITING_BIT, _state) {
                    break
                }
            } while true
        }

        // write lock acquired - run block
        return try body()
    }

    /// Call `body` with a reading lock.
    ///
    /// The given function may be called concurrently with reads on other threads.
    ///
    /// - parameter body: A function that reads a value while locked.
    /// - returns: The value returned from the given function.
    public func withReadLock<Return>(@noescape body: () throws -> Return) rethrows -> Return {
        // spin until we acquire read lock
        repeat {
            let state = _state.memory

            // if there is no writer and no writer waiting, try to increment reader count
            if (state & Masks.MASK_WRITER_BITS) == 0 &&
                OSAtomicCompareAndSwap32Barrier(state, state + 1, _state) {
                    break
            }
        } while true
        
        defer {
            // decrement reader count
            repeat {
                let state = _state.memory
                
                // sanity check that we have a positive reader count before decrementing it
                assert((state & Masks.MASK_READER_BITS) > 0, "unlocking read lock - invalid reader count")
                
                // desired new state: 1 fewer reader, preserving whether or not there is a writer waiting
                let newState = ((state & Masks.MASK_READER_BITS) - 1) |
                    (state & Masks.WRITER_WAITING_BIT)
                
                if OSAtomicCompareAndSwap32Barrier(state, newState, _state) {
                    break
                }
            } while true
        }

        // read lock acquired - run block
        return try body()
    }
}

/// A readers-writer lock provided by the platform implementation of the
/// POSIX Threads standard. Read more: https://en.wikipedia.org/wiki/POSIX_Threads
public final class PThreadReadWriteLock: ReadWriteLock {
    private var lock: UnsafeMutablePointer<pthread_rwlock_t>

    /// Create the standard platform lock.
    public init() {
        lock = UnsafeMutablePointer.alloc(1)
        let status = pthread_rwlock_init(lock, nil)
        assert(status == 0)
    }

    deinit {
        let status = pthread_rwlock_destroy(lock)
        assert(status == 0)
        lock.destroy()
        lock.dealloc(1)
    }

    /// Call `body` with a reading lock.
    ///
    /// The given function may be called concurrently with reads on other threads.
    ///
    /// - parameter body: A function that reads a value while locked.
    /// - returns: The value returned from the given function.
    public func withReadLock<Return>(@noescape body: () throws -> Return) rethrows -> Return {
        pthread_rwlock_rdlock(lock)
        defer {
            pthread_rwlock_unlock(lock)
        }
        return try body()
    }

    /// Call `body` with a writing lock.
    ///
    /// The given function is guaranteed to be called exclusively.
    ///
    /// - parameter body: A function that writes a value while locked, then returns some value.
    /// - returns: The value returned from the given function.
    public func withWriteLock<Return>(@noescape body: () throws -> Return) rethrows -> Return {
        pthread_rwlock_wrlock(lock)
        defer {
            pthread_rwlock_unlock(lock)
        }
        return try body()
    }

}
