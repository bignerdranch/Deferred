//
//  Locking.swift
//  Deferred
//
//  Created by John Gallagher on 7/17/14.
//  Copyright © 2014-2016 Big Nerd Ranch. Licensed under MIT.
//

import Dispatch
import Foundation

#if SWIFT_PACKAGE || COCOAPODS
import Atomics
#elseif XCODE
import Deferred.Atomics
#endif

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
}

protocol MaybeLocking: Locking {
    /// Attempt to call `body` with a reading lock.
    ///
    /// If the lock cannot immediately be taken, return `nil` instead of
    /// executing `body`.
    ///
    /// - returns: The value returned from the given function, or `nil`.
    /// - see: withReadLock(_:)
    func withAttemptedReadLock<Return>(_ body: () -> Return) -> Return?
}

/// A variant lock backed by a platform type that attempts to allow waiters to
/// block efficiently on contention. This locking type behaves the same for both
/// read and write locks.
///
/// - On recent versions of Darwin (iOS 10.0, macOS 12.0, tvOS 1.0, watchOS 3.0,
///   or better), this efficiency is a guarantee.
/// - On Linux, BSD, or Android, waiters perform comparably to a kernel lock
///   under contention.
public final class NativeLock: Locking, MaybeLocking {

    private var lock = UnsafeNativeLock()

    /// Creates a standard platform lock.
    public init() {
        bnr_native_lock_init(&lock)
    }

    deinit {
        bnr_native_lock_destroy(&lock)
    }

    public func withReadLock<Return>(_ body: () throws -> Return) rethrows -> Return {
        bnr_native_lock_lock(&lock)
        defer { bnr_native_lock_unlock(&lock) }
        return try body()
    }

    public func withAttemptedReadLock<Return>(_ body: () -> Return) -> Return? {
        guard bnr_native_lock_trylock(&lock) else { return nil }
        defer { bnr_native_lock_unlock(&lock) }
        return body()
    }

}

/// A readers-writer lock provided by the platform implementation of the
/// POSIX Threads standard. Read more: https://en.wikipedia.org/wiki/POSIX_Threads
public final class POSIXReadWriteLock: Locking, MaybeLocking {
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

    public func withReadLock<Return>(_ body: () throws -> Return) rethrows -> Return {
        pthread_rwlock_rdlock(&lock)
        defer {
            pthread_rwlock_unlock(&lock)
        }
        return try body()
    }

    public func withAttemptedReadLock<Return>(_ body: () -> Return) -> Return? {
        guard pthread_rwlock_tryrdlock(&lock) == 0 else { return nil }
        defer {
            pthread_rwlock_unlock(&lock)
        }
        return body()
    }

    public func withWriteLock<Return>(_ body: () throws -> Return) rethrows -> Return {
        pthread_rwlock_wrlock(&lock)
        defer {
            pthread_rwlock_unlock(&lock)
        }
        return try body()
    }
}

/// A locking construct using a counting semaphore from Grand Central Dispatch.
/// This locking type behaves the same for both read and write locks.
///
/// The semaphore lock performs comparably to a spinlock under little lock
/// contention, and comparably to a platform lock under contention.
extension DispatchSemaphore: Locking, MaybeLocking {
    private func withLock<Return>(before time: DispatchTime, body: () throws -> Return) rethrows -> Return? {
        guard case .success = wait(timeout: time) else { return nil }
        defer {
            signal()
        }
        return try body()

    }

    public func withReadLock<Return>(_ body: () throws -> Return) rethrows -> Return {
        return try withLock(before: .distantFuture, body: body)!
    }

    public func withAttemptedReadLock<Return>(_ body: () -> Return) -> Return? {
        return withLock(before: .now(), body: body)
    }
}

/// A lock object from the Foundation Kit used to coordinate the operation of
/// multiple threads of execution within the same application.
extension NSLock: Locking, MaybeLocking {
    public func withReadLock<Return>(_ body: () throws -> Return) rethrows -> Return {
        lock()
        defer {
            unlock()
        }
        return try body()
    }

    public func withAttemptedReadLock<Return>(_ body: () -> Return) -> Return? {
        guard `try`() else { return nil }
        defer {
            unlock()
        }
        return body()
    }
}
