//
//  ReadWriteLock.swift
//  ReadWriteLock
//
//  Created by John Gallagher on 7/17/14.
//  Copyright © 2014-2015 Big Nerd Ranch. Licensed under MIT.
//

import Dispatch
#if SWIFT_PACKAGE
import AtomicSwift
#endif

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

    /// Attempt to call `body` with a reading lock.
    ///
    /// If the lock cannot immediately be taken, return `nil` instead of
    /// executing `body`.
    ///
    /// - returns: The value returned from the given function, or `nil`.
    /// - seealso: withReadLock(_:)
    func withAttemptedReadLock<Return>(@noescape body: () throws -> Return) rethrows -> Return?

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

    private func withLock<Return>(timeout timeout: Timeout, @noescape body: () throws -> Return) rethrows -> Return? {
        guard dispatch_semaphore_wait(semaphore, timeout.rawValue) == 0 else { return nil }
        defer {
            dispatch_semaphore_signal(semaphore)
        }
        return try body()

    }

    /// Call `body` with a lock.
    /// - parameter body: A function that reads a value while locked.
    /// - returns: The value returned from the given function.
    public func withReadLock<Return>(@noescape body: () throws -> Return) rethrows -> Return {
        return try withLock(timeout: .Forever, body: body)!
    }

    /// Attempt to call `body` with a lock.
    /// - returns: The value returned from `body`, or `nil` if already locked.
    /// - seealso: withReadLock(_:)
    public func withAttemptedReadLock<Return>(@noescape body: () throws -> Return) rethrows -> Return? {
        return try withLock(timeout: .Now, body: body)
    }
}

/// A spin lock provided by Darwin, the low-level system under iOS and OS X.
///
/// A spin lock polls to check the state of the lock, which is much faster
/// when there isn't contention but rapidly slows down otherwise.
public final class SpinLock: ReadWriteLock {
    private var lock = OS_SPINLOCK_INIT

    /// Allocate a normal spinlock.
    public init() {}

    /// Call `body` with a lock.
    /// - parameter body: A function that reads a value while locked.
    /// - returns: The value returned from the given function.
    public func withReadLock<Return>(@noescape body: () throws -> Return) rethrows -> Return {
        OSSpinLockLock(&lock)
        defer {
            OSSpinLockUnlock(&lock)
        }
        return try body()
    }

    /// Attempt to call `body` with a lock.
    /// - returns: The value returned from `body`, or `nil` if already locked.
    /// - seealso: withReadLock(_:)
    public func withAttemptedReadLock<Return>(@noescape body: () throws -> Return) rethrows -> Return? {
        guard OSSpinLockTry(&lock) else { return nil }
        defer {
            OSSpinLockUnlock(&lock)
        }
        return try body()
    }
}

/// A custom spin-lock with readers-writer semantics. The spin lock will poll
/// to check the state of the lock, allowing many readers at the same time.
public final class CASSpinLock: ReadWriteLock {
    // Original inspiration: http://joeduffyblog.com/2009/01/29/a-singleword-readerwriter-spin-lock/
    // Updated/optimized version: https://jfdube.wordpress.com/2014/01/12/optimizing-the-recursive-read-write-spinlock/
    private enum Constants {
        static var WriterMask:   Int32 { return Int32(bitPattern: 0xFFF00000) }
        static var ReaderMask:   Int32 { return Int32(bitPattern: 0x000FFFFF) }
        static var WriterOffset: Int32 { return Int32(bitPattern: 0x00100000) }
    }

    private var state = Int32.allZeros

    /// Allocate the spinlock.
    public init() {}

    /// Call `body` with a writing lock.
    ///
    /// The given function is guaranteed to be called exclusively.
    ///
    /// - parameter body: A function that writes a value while locked, then returns some value.
    /// - returns: The value returned from the given function.
    public func withWriteLock<Return>(@noescape body: () throws -> Return) rethrows -> Return {
        // spin until we acquire write lock
        repeat {
            // wait for any active writer to release the lock
            while (state & Constants.WriterMask) != 0 {
                _OSAtomicSpin()
            }

            // increment the writer count
            if (OSAtomicAdd32Barrier(Constants.WriterOffset, &state) & Constants.WriterMask) == Constants.WriterOffset {
                // wait until there are no more readers
                while (state & Constants.ReaderMask) != 0 {
                    _OSAtomicSpin()
                }

                // write lock acquired
                break
            }

            // there's another writer active; try again
            OSAtomicAdd32Barrier(-Constants.WriterOffset, &state)
        } while true
        
        defer {
            // decrement writers, potentially unblock readers
            OSAtomicAdd32Barrier(-Constants.WriterOffset, &state)
        }

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
            // wait for active writer to release the lock
            while (state & Constants.WriterMask) != 0 {
                _OSAtomicSpin()
            }

            // increment the reader count
            if (OSAtomicIncrement32Barrier(&state) & Constants.WriterMask) == 0 {
                // read lock required
                break
            }

            // a writer became active while locking; try again
            OSAtomicDecrement32Barrier(&state)
        } while true
        
        defer {
            // decrement readers, potentially unblock writers
            OSAtomicDecrement32Barrier(&state)
        }

        return try body()
    }

    /// Attempt to call `body` with a lock.
    ///
    /// `body` may be called concurrently with reads on other threads.
    ///
    /// - returns: The value returned from `body`, or `nil` if already locked.
    /// - seealso: withReadLock(_:)
    public func withAttemptedReadLock<Return>(@noescape body: () throws -> Return) rethrows -> Return? {
        // active writer
        guard (state & Constants.WriterMask) == 0 else { return nil }

        // increment the reader count
        guard (OSAtomicIncrement32Barrier(&state) & Constants.WriterMask) == 0 else { return nil }

        defer {
            // decrement readers, potentially unblock writers
            OSAtomicDecrement32Barrier(&state)
        }

        return try body()
    }
}

/// A readers-writer lock provided by the platform implementation of the
/// POSIX Threads standard. Read more: https://en.wikipedia.org/wiki/POSIX_Threads
public final class PThreadReadWriteLock: ReadWriteLock {
    private var lock = pthread_rwlock_t()

    /// Create the standard platform lock.
    public init() {
        let status = pthread_rwlock_init(&lock, nil)
        assert(status == 0)
    }

    deinit {
        let status = pthread_rwlock_destroy(&lock)
        assert(status == 0)
    }

    /// Call `body` with a reading lock.
    ///
    /// The given function may be called concurrently with reads on other threads.
    ///
    /// - parameter body: A function that reads a value while locked.
    /// - returns: The value returned from the given function.
    public func withReadLock<Return>(@noescape body: () throws -> Return) rethrows -> Return {
        pthread_rwlock_rdlock(&lock)
        defer {
            pthread_rwlock_unlock(&lock)
        }
        return try body()
    }

    /// Attempt to call `body` with a lock.
    ///
    /// `body` may be called concurrently with reads on other threads.
    ///
    /// - returns: The value returned from `body`, or `nil` if already locked.
    /// - seealso: withReadLock(_:)
    public func withAttemptedReadLock<Return>(@noescape body: () throws -> Return) rethrows -> Return? {
        guard pthread_rwlock_tryrdlock(&lock) == 0 else { return nil }
        defer {
            pthread_rwlock_unlock(&lock)
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
        pthread_rwlock_wrlock(&lock)
        defer {
            pthread_rwlock_unlock(&lock)
        }
        return try body()
    }

}
