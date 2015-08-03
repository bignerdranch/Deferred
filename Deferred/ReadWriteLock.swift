//
//  ReadWriteLock.swift
//  ReadWriteLock
//
//  Created by John Gallagher on 7/17/14.
//  Copyright © 2014-2015 Big Nerd Ranch. Licensed under MIT.
//

import Foundation

public protocol ReadWriteLock {
    func withReadLock<T>(@noescape body: () -> T) -> T
    func withWriteLock<T>(@noescape body: () -> T) -> T
}

public struct DispatchLock: ReadWriteLock {
    private let semaphore = dispatch_semaphore_create(1)

    public init() {}

    private func withLock<T>(@noescape body: () -> T) -> T {
        let result: T
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
        result = body()
        dispatch_semaphore_signal(semaphore)
        return result
    }

    public func withReadLock<T>(@noescape body: () -> T) -> T {
        return withLock(body)
    }

    public func withWriteLock<T>(@noescape body: () -> T) -> T {
        return withLock(body)
    }
}

public final class SpinLock: ReadWriteLock {
    private var lock: UnsafeMutablePointer<OSSpinLock>

    public init() {
        lock = UnsafeMutablePointer.alloc(1)
        lock.initialize(OS_SPINLOCK_INIT)
    }

    deinit {
        lock.dealloc(1)
    }

    private func withLock<T>(@noescape body: () -> T) -> T {
        let result: T
        OSSpinLockLock(lock)
        result = body()
        OSSpinLockUnlock(lock)
        return result
    }

    public func withReadLock<T>(@noescape body: () -> T) -> T {
        return withLock(body)
    }

    public func withWriteLock<T>(@noescape body: () -> T) -> T {
        return withLock(body)
    }
}

/// Test comment 2
public final class CASSpinLock: ReadWriteLock {
    private struct Masks {
        static let WRITER_BIT: Int32         = 0x40000000
        static let WRITER_WAITING_BIT: Int32 = 0x20000000
        static let MASK_WRITER_BITS          = WRITER_BIT | WRITER_WAITING_BIT
        static let MASK_READER_BITS          = ~MASK_WRITER_BITS
    }

    private var _state: UnsafeMutablePointer<Int32>

    public init() {
        _state = UnsafeMutablePointer.alloc(1)
        _state.memory = 0
    }

    deinit {
        _state.dealloc(1)
    }

    public func withWriteLock<T>(@noescape body: () -> T) -> T {
        // spin until we acquire write lock
        do {
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

        // write lock acquired - run block
        let result = body()

        // unlock
        do {
            let state = _state.memory

            // clear everything except (possibly) WRITER_WAITING_BIT, which will only be set
            // if another writer is already here and waiting (which will keep out readers)
            if OSAtomicCompareAndSwap32Barrier(state, state & Masks.WRITER_WAITING_BIT, _state) {
                break
            }
        } while true

        return result
    }

    public func withReadLock<T>(@noescape body: () -> T) -> T {
        // spin until we acquire read lock
        do {
            let state = _state.memory

            // if there is no writer and no writer waiting, try to increment reader count
            if (state & Masks.MASK_WRITER_BITS) == 0 &&
                OSAtomicCompareAndSwap32Barrier(state, state + 1, _state) {
                    break
            }
        } while true

        // read lock acquired - run block
        let result = body()

        // decrement reader count
        do {
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

        return result
    }
}

public final class PThreadReadWriteLock: ReadWriteLock {
    private var lock: UnsafeMutablePointer<pthread_rwlock_t>

    public init() {
        lock = UnsafeMutablePointer.alloc(1)
        let status = pthread_rwlock_init(lock, nil)
        assert(status == 0)
    }

    deinit {
        let status = pthread_rwlock_destroy(lock)
        assert(status == 0)
        lock.dealloc(1)
    }

    public func withReadLock<T>(@noescape body: () -> T) -> T {
        let result: T
        pthread_rwlock_rdlock(lock)
        result = body()
        pthread_rwlock_unlock(lock)
        return result
    }

    public func withWriteLock<T>(@noescape body: () -> T) -> T {
        let result: T
        pthread_rwlock_wrlock(lock)
        result = body()
        pthread_rwlock_unlock(lock)
        return result
    }

}
