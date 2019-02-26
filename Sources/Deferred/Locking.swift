//
//  Locking.swift
//  Deferred
//
//  Created by John Gallagher on 7/17/14.
//  Copyright © 2014-2019 Big Nerd Ranch. Licensed under MIT.
//

import Dispatch
import Foundation

/// A type that mutually excludes execution of code such that only one unit of
/// code is running at any given time. An implementing type may choose to have
/// readers-writer semantics, such that many readers can read at once, or lock
/// around all reads and writes the same way.
public protocol Locking {
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
    /// - see: withReadLock(_:)
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

extension Locking {
    public func withWriteLock<Return>(_ body: () throws -> Return) rethrows -> Return {
        return try withReadLock(body)
    }

    public func withAttemptedReadLock<Return>(_ body: () throws -> Return) rethrows -> Return? {
        return try withReadLock(body)
    }
}

/// A variant lock backed by a platform type that attempts to allow waiters to
/// block efficiently on contention. This locking type behaves the same for both
/// read and write locks.
///
/// - On recent versions of Darwin (iOS 10.0, macOS 12.0, tvOS 1.0, watchOS 3.0,
///   or better), this efficiency is a guarantee.
/// - On Linux, BSD, or Android, waiters perform comparably to a kernel lock
///   under contention.
public final class NativeLock: Locking {
    private let lock: UnsafeMutableRawPointer

    /// Creates a standard platform lock.
    public init() {
        #if canImport(os)
        if #available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
            let lock = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
            lock.initialize(to: os_unfair_lock())
            self.lock = UnsafeMutableRawPointer(lock)
            return
        }
        #endif

        let lock = UnsafeMutablePointer<pthread_mutex_t>.allocate(capacity: 1)
        lock.initialize(to: pthread_mutex_t())
        pthread_mutex_init(lock, nil)
        self.lock = UnsafeMutableRawPointer(lock)
    }

    deinit {
        #if canImport(os)
        if #available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
            let lock = self.lock.assumingMemoryBound(to: os_unfair_lock.self)
            lock.deinitialize(count: 1)
            lock.deallocate()
            return
        }
        #endif

        let lock = self.lock.assumingMemoryBound(to: pthread_mutex_t.self)
        pthread_mutex_destroy(lock)
        lock.deinitialize(count: 1)
        lock.deallocate()
    }

    public func withReadLock<Return>(_ body: () throws -> Return) rethrows -> Return {
        #if canImport(os)
        if #available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
            let lock = self.lock.assumingMemoryBound(to: os_unfair_lock.self)
            os_unfair_lock_lock(lock)
            defer {
                os_unfair_lock_unlock(lock)
            }
            return try body()
        }
        #endif

        let lock = self.lock.assumingMemoryBound(to: pthread_mutex_t.self)
        pthread_mutex_lock(lock)
        defer {
            pthread_mutex_unlock(lock)
        }
        return try body()
    }

    public func withAttemptedReadLock<Return>(_ body: () throws -> Return) rethrows -> Return? {
        #if canImport(os)
        if #available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
            let lock = self.lock.assumingMemoryBound(to: os_unfair_lock.self)
            guard os_unfair_lock_trylock(lock) else { return nil }
            defer {
                os_unfair_lock_unlock(lock)
            }
            return try body()
        }
        #endif

        let lock = self.lock.assumingMemoryBound(to: pthread_mutex_t.self)
        guard pthread_mutex_trylock(lock) == 0 else { return nil }
        defer {
            pthread_mutex_unlock(lock)
        }
        return try body()
    }
}

/// A readers-writer lock provided by the platform implementation of the
/// POSIX Threads standard. Read more: https://en.wikipedia.org/wiki/POSIX_Threads
public final class POSIXReadWriteLock: Locking {
    private let lock: UnsafeMutablePointer<pthread_rwlock_t>

    /// Create the standard platform lock.
    public init() {
        lock = UnsafeMutablePointer<pthread_rwlock_t>.allocate(capacity: 1)
        lock.initialize(to: pthread_rwlock_t())
        pthread_rwlock_init(lock, nil)
    }

    deinit {
        pthread_rwlock_destroy(lock)
        lock.deinitialize(count: 1)
        lock.deallocate()
    }

    public func withReadLock<Return>(_ body: () throws -> Return) rethrows -> Return {
        pthread_rwlock_rdlock(lock)
        defer {
            pthread_rwlock_unlock(lock)
        }
        return try body()
    }

    public func withAttemptedReadLock<Return>(_ body: () throws -> Return) rethrows -> Return? {
        guard pthread_rwlock_tryrdlock(lock) == 0 else { return nil }
        defer {
            pthread_rwlock_unlock(lock)
        }
        return try body()
    }

    public func withWriteLock<Return>(_ body: () throws -> Return) rethrows -> Return {
        pthread_rwlock_wrlock(lock)
        defer {
            pthread_rwlock_unlock(lock)
        }
        return try body()
    }
}

/// A locking construct using a counting semaphore from Grand Central Dispatch.
/// This locking type behaves the same for both read and write locks.
///
/// The semaphore lock performs comparably to a spinlock under little lock
/// contention, and comparably to a platform lock under contention.
extension DispatchSemaphore: Locking {
    public func withReadLock<Return>(_ body: () throws -> Return) rethrows -> Return {
        _ = wait(timeout: .distantFuture)
        defer {
            signal()
        }
        return try body()
    }

    public func withAttemptedReadLock<Return>(_ body: () throws -> Return) rethrows -> Return? {
        guard case .success = wait(timeout: .now()) else { return nil }
        defer {
            signal()
        }
        return try body()
    }
}

/// A lock object from the Foundation Kit used to coordinate the operation of
/// multiple threads of execution within the same application.
extension NSLock: Locking {
    public func withReadLock<Return>(_ body: () throws -> Return) rethrows -> Return {
        lock()
        defer {
            unlock()
        }
        return try body()
    }

    public func withAttemptedReadLock<Return>(_ body: () throws -> Return) rethrows -> Return? {
        guard `try`() else { return nil }
        defer {
            unlock()
        }
        return try body()
    }
}
