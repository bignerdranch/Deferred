//
//  ReadWriteLock.swift
//  ReadWriteLock
//
//  Created by John Gallagher on 7/17/14.
//  Copyright (c) 2014 Big Nerd Ranch. All rights reserved.
//

import Foundation

public protocol ReadWriteLock {
    mutating func withReadLock<T>(block: () -> T) -> T
    mutating func withWriteLock<T>(block: () -> T) -> T
}

public struct GCDReadWriteLock: ReadWriteLock {
    private let queue = dispatch_queue_create("GCDReadWriteLock", DISPATCH_QUEUE_CONCURRENT)

    public init() {}

    public func withReadLock<T>(block: () -> T) -> T {
        var result: T!
        dispatch_sync(queue) {
            result = block()
        }
        return result
    }

    public func withWriteLock<T>(block: () -> T) -> T {
        var result: T!
        dispatch_barrier_sync(queue) {
            result = block()
        }
        return result
    }
}

public struct SpinLock: ReadWriteLock {
    private var lock = OS_SPINLOCK_INIT

    public init() {}

    public mutating func withReadLock<T>(block: () -> T) -> T {
        OSSpinLockLock(&lock)
        let result = block()
        OSSpinLockUnlock(&lock)
        return result
    }

    public mutating func withWriteLock<T>(block: () -> T) -> T {
        OSSpinLockLock(&lock)
        let result = block()
        OSSpinLockUnlock(&lock)
        return result
    }
}

/// Test comment 2
public struct CASSpinLock: ReadWriteLock {
    private static let WRITER_BIT: Int32         = 0x40000000
    private static let WRITER_WAITING_BIT: Int32 = 0x20000000
    private static let MASK_WRITER_BITS          = WRITER_BIT | WRITER_WAITING_BIT
    private static let MASK_READER_BITS          = ~MASK_WRITER_BITS

    private var _state: Int32 = 0

    public init() {}

    public mutating func withWriteLock<T>(block: () -> T) -> T {
        // spin until we acquire write lock
        do {
            let state = _state

            // if there are no readers and no one holds the write lock, try to grab the write lock immediately
            if (state == 0 || state == CASSpinLock.WRITER_WAITING_BIT) &&
                OSAtomicCompareAndSwap32Barrier(state, CASSpinLock.WRITER_BIT, &_state) {
                    break
            }

            // If we get here, someone is reading or writing. Set the WRITER_WAITING_BIT if
            // it isn't already to block any new readers, then wait a bit before
            // trying again. Ignore CAS failure - we'll just try again next iteration
            if state & CASSpinLock.WRITER_WAITING_BIT == 0 {
                OSAtomicCompareAndSwap32Barrier(state, state | CASSpinLock.WRITER_WAITING_BIT, &_state)
            }
        } while true

        // write lock acquired - run block
        let result = block()

        // unlock
        do {
            let state = _state

            // clear everything except (possibly) WRITER_WAITING_BIT, which will only be set
            // if another writer is already here and waiting (which will keep out readers)
            if OSAtomicCompareAndSwap32Barrier(state, state & CASSpinLock.WRITER_WAITING_BIT, &_state) {
                break
            }
        } while true

        return result
    }

    public mutating func withReadLock<T>(block: () -> T) -> T {
        // spin until we acquire read lock
        do {
            let state = _state

            // if there is no writer and no writer waiting, try to increment reader count
            if (state & CASSpinLock.MASK_WRITER_BITS) == 0 &&
                OSAtomicCompareAndSwap32Barrier(state, state + 1, &_state) {
                    break
            }
        } while true

        // read lock acquired - run block
        let result = block()

        // decrement reader count
        do {
            let state = _state

            // sanity check that we have a positive reader count before decrementing it
            assert((state & CASSpinLock.MASK_READER_BITS) > 0, "unlocking read lock - invalid reader count")

            // desired new state: 1 fewer reader, preserving whether or not there is a writer waiting
            let newState = ((state & CASSpinLock.MASK_READER_BITS) - 1) |
                (state & CASSpinLock.WRITER_WAITING_BIT)

            if OSAtomicCompareAndSwap32Barrier(state, newState, &_state) {
                break
            }
        } while true

        return result
    }
}