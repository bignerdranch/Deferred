//
//  ReadWriteLock.swift
//  ReadWriteLock
//
//  Created by John Gallagher on 7/17/14.
//  Copyright © 2014-2015 Big Nerd Ranch. Licensed under MIT.
//

import Dispatch
import Atomics

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
    func withReadLock<Return>(_ body: () throws -> Return) rethrows -> Return

    /// Attempt to call `body` with a reading lock.
    ///
    /// If the lock cannot immediately be taken, return `nil` instead of
    /// executing `body`.
    ///
    /// - returns: The value returned from the given function, or `nil`.
    /// - seealso: withReadLock(_:)
    func withAttemptedReadLock<Return>(_ body: () throws -> Return) rethrows -> Return?

    /// Call `body` with a writing lock.
    ///
    /// If the implementing type models a readers-writer lock, this function may
    /// behave differently to `withReadLock(_:)`.
    ///
    /// - parameter body: A function that writes a value while locked, then returns some value.
    /// - returns: The value returned from the given function.
    func withWriteLock<Return>(_ body: () throws -> Return) rethrows -> Return
}

extension ReadWriteLock {
    /// Call `body` with a lock.
    ///
    /// - parameter body: A function that writes a value while locked, then returns some value.
    /// - returns: The value returned from the given function.
    public func withWriteLock<Return>(_ body: () throws -> Return) rethrows -> Return {
        return try withReadLock(body)
    }
}

/// A locking construct using a counting semaphore from Grand Central Dispatch.
/// This locking type behaves the same for both read and write locks.
///
/// The semaphore lock performs comparably to a spinlock under little lock
/// contention, and comparably to a platform lock under contention.
public struct DispatchLock: ReadWriteLock {
    private let semaphore = DispatchSemaphore(value: 1)

    /// Create a normal instance.
    public init() {}

    private func withLock<Return>(before time: DispatchTime, body: () throws -> Return) rethrows -> Return? {
        guard case .success = semaphore.wait(timeout: time) else { return nil }
        defer {
            semaphore.signal()
        }
        return try body()

    }

    /// Call `body` with a lock.
    /// - parameter body: A function that reads a value while locked.
    /// - returns: The value returned from the given function.
    public func withReadLock<Return>(_ body: () throws -> Return) rethrows -> Return {
        return try withLock(before: .distantFuture, body: body)!
    }

    /// Attempt to call `body` with a lock.
    /// - returns: The value returned from `body`, or `nil` if already locked.
    /// - seealso: withReadLock(_:)
    public func withAttemptedReadLock<Return>(_ body: () throws -> Return) rethrows -> Return? {
        return try withLock(before: .now(), body: body)
    }
}

/// An unfair lock provided by the platform.
///
/// A spin lock conceptually polls to check the state of the lock, which is much
/// faster when there isn't contention expected. No attempts at fairness or lock
/// ordering are made.
///
/// In iOS 10.0, macOS 12.0, tvOS 1.0, watchOS 3.0, or better, the
/// implementation does not actually spin on contention.
///
/// On prior versions of Darwin, or any platform that eagerly suspends threads
/// for QoS, this may cause unexpected priority inversion, and should be used
/// with care.
public final class SpinLock: ReadWriteLock {
    private var lock = UnsafeSpinLock()

    /// Allocate a normal spinlock.
    public init() {}

    /// Call `body` with a lock.
    /// - parameter body: A function that reads a value while locked.
    /// - returns: The value returned from the given function.
    public func withReadLock<Return>(_ body: () throws -> Return) rethrows -> Return {
        lock.lock()
        defer {
            lock.unlock()
        }
        return try body()
    }

    /// Attempt to call `body` with a lock.
    /// - returns: The value returned from `body`, or `nil` if already locked.
    /// - seealso: withReadLock(_:)
    public func withAttemptedReadLock<Return>(_ body: () throws -> Return) rethrows -> Return? {
        guard lock.tryLock() else { return nil }
        defer {
            lock.unlock()
        }
        return try body()
    }
}

/// A custom spin-lock with readers-writer semantics.
///
/// A spin lock will poll to check the state of the lock, which is much faster
/// when there isn't contention expected. In addition, this lock attempts to
/// allow many readers at the same time.
///
/// On Darwin, or any platform that eagerly suspends threads for QoS, this may
/// cause unexpected priority inversion, and should be used with care.
public final class CASSpinLock: ReadWriteLock {
    // Original inspiration: http://joeduffyblog.com/2009/01/29/a-singleword-readerwriter-spin-lock/
    // Updated/optimized version: https://jfdube.wordpress.com/2014/01/12/optimizing-the-recursive-read-write-spinlock/
    private enum Constants {
        static var WriterMask:   Int32 { return Int32(bitPattern: 0xFFF00000) }
        static var ReaderMask:   Int32 { return Int32(bitPattern: 0x000FFFFF) }
        static var WriterOffset: Int32 { return Int32(bitPattern: 0x00100000) }
    }

    private var state = UnsafeAtomicInt32()

    /// Allocate the spinlock.
    public init() {}

    /// Call `body` with a writing lock.
    ///
    /// The given function is guaranteed to be called exclusively.
    ///
    /// - parameter body: A function that writes a value while locked, then returns some value.
    /// - returns: The value returned from the given function.
    public func withWriteLock<Return>(_ body: () throws -> Return) rethrows -> Return {
        // spin until we acquire write lock
        repeat {
            // wait for any active writer to release the lock
            while (state.load(order: .relaxed) & Constants.WriterMask) != 0 {
                UnsafeAtomicInt32.spin()
            }

            // increment the writer count
            if (state.add(Constants.WriterOffset, order: .acquire) & Constants.WriterMask) == Constants.WriterOffset {
                // wait until there are no more readers
                while (state.load(order: .relaxed) & Constants.ReaderMask) != 0 {
                    UnsafeAtomicInt32.spin()
                }

                // write lock acquired
                break
            }

            // there's another writer active; try again
            state.subtract(Constants.WriterOffset, order: .release)
        } while true
        
        defer {
            // decrement writers, potentially unblock readers
            state.subtract(Constants.WriterOffset, order: .release)
        }

        return try body()
    }

    /// Call `body` with a reading lock.
    ///
    /// The given function may be called concurrently with reads on other threads.
    ///
    /// - parameter body: A function that reads a value while locked.
    /// - returns: The value returned from the given function.
    public func withReadLock<Return>(_ body: () throws -> Return) rethrows -> Return {
        // spin until we acquire read lock
        repeat {
            // wait for active writer to release the lock
            while (state.load(order: .relaxed) & Constants.WriterMask) != 0 {
                UnsafeAtomicInt32.spin()
            }

            // increment the reader count
            if (state.add(1, order: .acquire) & Constants.WriterMask) == 0 {
                // read lock required
                break
            }

            // a writer became active while locking; try again
            state.subtract(1, order: .release)
        } while true
        
        defer {
            // decrement readers, potentially unblock writers
            state.subtract(1, order: .release)
        }

        return try body()
    }

    /// Attempt to call `body` with a lock.
    ///
    /// `body` may be called concurrently with reads on other threads.
    ///
    /// - returns: The value returned from `body`, or `nil` if already locked.
    /// - seealso: withReadLock(_:)
    public func withAttemptedReadLock<Return>(_ body: () throws -> Return) rethrows -> Return? {
        // active writer
        guard (state.load(order: .relaxed) & Constants.WriterMask) == 0 else { return nil }

        // increment the reader count
        guard (state.add(1, order: .acquire) & Constants.WriterMask) == 0 else {
            state.subtract(1, order: .release)
            return nil
        }

        defer {
            // decrement readers, potentially unblock writers
            state.subtract(1, order: .release)
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
    public func withReadLock<Return>(_ body: () throws -> Return) rethrows -> Return {
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
    public func withAttemptedReadLock<Return>(_ body: () throws -> Return) rethrows -> Return? {
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
    public func withWriteLock<Return>(_ body: () throws -> Return) rethrows -> Return {
        pthread_rwlock_wrlock(&lock)
        defer {
            pthread_rwlock_unlock(&lock)
        }
        return try body()
    }

}
