//
//  ReadWriteLockTests.swift
//  ReadWriteLockTests
//
//  Created by John Gallagher on 7/19/14.
//  Copyright © 2014-2015 Big Nerd Ranch. Licensed under MIT.
//

import XCTest
@testable import Deferred
import AtomicSwift

func timeIntervalSleep(duration: NSTimeInterval) {
    usleep(useconds_t(duration * NSTimeInterval(USEC_PER_SEC)))
}

private let testTimeout = 10.0

class PerfTestThread: NSThread {
    let iters: Int
    var lock: ReadWriteLock
    let joinLock = NSConditionLock(condition: 0)

    init(lock: ReadWriteLock, iters: Int) {
        self.lock = lock
        self.iters = iters
        super.init()
    }

    override func main() {
        joinLock.lock()
        let doNothing: () -> () = {}
        for i in 0 ..< iters {
            if (i % 10) == 0 {
                lock.withWriteLock(doNothing)
            } else {
                lock.withReadLock(doNothing)
            }
        }
        joinLock.unlockWithCondition(1)
    }

    func join() {
        joinLock.lockWhenCondition(1)
        joinLock.unlock()
    }
}

class ReadWriteLockTests: XCTestCase {
    var dispatchLock: DispatchLock!
    var spinLock: SpinLock!
    var casSpinLock: CASSpinLock!
    var pthreadLock: PThreadReadWriteLock!
    var queue: dispatch_queue_t!
    var allLocks: [ReadWriteLock]!
    var locksAllowingConcurrentReads: [ReadWriteLock]!

    override func setUp() {
        super.setUp()

        dispatchLock = DispatchLock()
        spinLock = SpinLock()
        casSpinLock = CASSpinLock()
        pthreadLock = PThreadReadWriteLock()

        allLocks = [dispatchLock, spinLock, casSpinLock, pthreadLock]
        locksAllowingConcurrentReads = [casSpinLock, pthreadLock]

        queue = dispatch_queue_create("ReadWriteLockTests", DISPATCH_QUEUE_CONCURRENT)
    }

    override func tearDown() {
        queue = nil

        allLocks = nil
        locksAllowingConcurrentReads = nil

        casSpinLock = nil
        spinLock = nil
        dispatchLock = nil
        pthreadLock = nil

        super.tearDown()
    }

    func testMultipleConcurrentReaders() {
        for lock in locksAllowingConcurrentReads {
            // start up 32 readers that block for 0.1 seconds each...
            for _ in 0 ..< 32 {
                let expectation = expectationWithDescription("read \(lock)")
                dispatch_async(queue) {
                    lock.withReadLock {
                        timeIntervalSleep(0.1)
                        expectation.fulfill()
                    }
                }
            }

            // and make sure all 32 complete in < 3 second. If the readers
            // did not run concurrently, they would take >= 3.2 seconds
            waitForExpectationsWithTimeout(testTimeout, handler: nil)
        }
    }

    func testMultipleConcurrentWriters() {
        for lock in allLocks {
            var x: Int32 = 0

            // spin up 5 writers concurrently...
            for i in 0 ..< 5 {
                let expectation = expectationWithDescription("write \(lock) #\(i)")
                dispatch_async(queue) {
                    lock.withWriteLock {
                        // ... and make sure each runs in order by checking that
                        // no two blocks increment x at the same time
                        XCTAssertEqual(__bnr_atomic_increment_32(&x), 1)
                        timeIntervalSleep(0.05)
                        XCTAssertEqual(__bnr_atomic_decrement_32(&x), 0)
                        expectation.fulfill()
                    }
                }
            }
            waitForExpectationsWithTimeout(testTimeout, handler: nil)
        }
    }

    func testSimultaneousReadersAndWriters() {
        for lock in allLocks {
            var x: Int32 = 0

            let startReader: (Int) -> () = { i in
                let expectation = self.expectationWithDescription("reader \(i)")
                dispatch_async(self.queue) {
                    lock.withReadLock {
                        // make sure we get the value of x either before or after
                        // the writer runs, never a partway-through value
                        XCTAssertTrue(x == 0 || x == 5)
                        expectation.fulfill()
                    }
                }
            }

            // spin up 32 readers before a writer
            for i in 0 ..< 32 {
                startReader(i)
            }
            // spin up a writer that (slowly) increments x from 0 to 5
            let expectation = expectationWithDescription("writer")
            dispatch_async(queue) {
                lock.withWriteLock {
                    for _ in 0 ..< 5 {
                        __bnr_atomic_increment_32(&x)
                        timeIntervalSleep(0.1)
                    }
                    expectation.fulfill()
                }
            }
            // and spin up 32 more readers after
            for i in 32 ..< 64 {
                startReader(i)
            }

            waitForExpectationsWithTimeout(testTimeout, handler: nil)
        }
    }

    func measureReadLockSingleThread(lock: ReadWriteLock, iters: Int) {
        let doNothing: () -> () = {}
        self.measureBlock {
            for _ in 0 ..< iters {
                lock.withReadLock(doNothing)
            }
        }
    }

    func measureWriteLockSingleThread(lock: ReadWriteLock, iters: Int) {
        let doNothing: () -> () = {}
        self.measureBlock {
            for _ in 0 ..< iters {
                lock.withWriteLock(doNothing)
            }
        }
    }

    func measureLock90PercentReadsNThreads(lock: ReadWriteLock, iters: Int, nthreads: Int) {
        self.measureBlock {
            var threads: [PerfTestThread] = []
            for _ in 0 ..< nthreads {
                let t = PerfTestThread(lock: lock, iters: iters)
                t.start()
                threads.append(t)
            }
            for t in threads {
                t.join()
            }
        }
    }

    func testSingleThreadPerformanceGCDLockRead() {
        measureReadLockSingleThread(dispatchLock, iters: 250_000)
    }
    func testSingleThreadPerformanceGCDLockWrite() {
        measureWriteLockSingleThread(dispatchLock, iters: 250_000)
    }

    func testSingleThreadPerformanceSpinLockRead() {
        measureReadLockSingleThread(spinLock, iters: 250_000)
    }
    func testSingleThreadPerformanceSpinLockWrite() {
        measureWriteLockSingleThread(spinLock, iters: 250_000)
    }

    func testSingleThreadPerformanceCASSpinLockRead() {
        measureReadLockSingleThread(casSpinLock, iters: 250_000)
    }
    func testSingleThreadPerformanceCASSpinLockWrite() {
        measureWriteLockSingleThread(casSpinLock, iters: 250_000)
    }

    func testSingleThreadPerformancePThreadLockRead() {
        measureReadLockSingleThread(pthreadLock, iters: 250_000)
    }
    func testSingleThreadPerformancePThreadLockWrite() {
        measureWriteLockSingleThread(pthreadLock, iters: 250_000)
    }

    func test90PercentReads4ThreadsGCDLock() {
        measureLock90PercentReadsNThreads(dispatchLock, iters: 5_000, nthreads: 4)
    }
    func test90PercentReads4ThreadsSpinLock() {
        measureLock90PercentReadsNThreads(spinLock, iters: 5_000, nthreads: 4)
    }
    func test90PercentReads4ThreadsCASSpinLock() {
        measureLock90PercentReadsNThreads(casSpinLock, iters: 5_000, nthreads: 4)
    }
    func test90PercentReads4ThreadsPThreadLock() {
        measureLock90PercentReadsNThreads(pthreadLock, iters: 5_000, nthreads: 4)
    }

}
