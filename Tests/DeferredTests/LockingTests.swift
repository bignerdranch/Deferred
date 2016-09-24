//
//  LockingTests.swift
//  DeferredTests
//
//  Created by John Gallagher on 7/19/14.
//  Copyright © 2014-2016 Big Nerd Ranch. Licensed under MIT.
//

import XCTest
import Dispatch
import typealias Foundation.TimeInterval

import Deferred
import Atomics
#if SWIFT_PACKAGE
@testable import TestSupport
#endif

func timeIntervalSleep(_ duration: TimeInterval) {
    usleep(useconds_t(duration * TimeInterval(1_000_000)))
}

class LockingTests: XCTestCase {
    static var allTests: [(String, (LockingTests) -> () throws -> Void)] {
        let universalTests: [(String, (LockingTests) -> () throws -> Void)] = [
            ("testMultipleConcurrentReaders", testMultipleConcurrentReaders),
            ("testMultipleConcurrentWriters", testMultipleConcurrentWriters),
            ("testSimultaneousReadersAndWriters", testSimultaneousReadersAndWriters),
            ("testSingleThreadPerformanceGCDLockRead", testSingleThreadPerformanceGCDLockRead),
            ("testSingleThreadPerformanceGCDLockWrite", testSingleThreadPerformanceGCDLockWrite),
            ("testSingleThreadPerformanceSpinLockRead", testSingleThreadPerformanceSpinLockRead),
            ("testSingleThreadPerformanceSpinLockWrite", testSingleThreadPerformanceSpinLockWrite),
            ("testSingleThreadPerformanceCASSpinLockRead", testSingleThreadPerformanceCASSpinLockRead),
            ("testSingleThreadPerformanceCASSpinLockWrite", testSingleThreadPerformanceCASSpinLockWrite),
            ("testSingleThreadPerformancePThreadReadWriteLockRead", testSingleThreadPerformancePThreadReadWriteLockRead),
            ("testSingleThreadPerformancePThreadReadWriteLockWrite", testSingleThreadPerformancePThreadReadWriteLockWrite),
        ]

        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        let appleTests: [(String, (LockingTests) -> () throws -> Void)] = [
            ("test90PercentReads4ThreadsGCDLock", test90PercentReads4ThreadsGCDLock),
            ("test90PercentReads4ThreadsSpinLock", test90PercentReads4ThreadsSpinLock),
            ("test90PercentReads4ThreadsCASSpinLock", test90PercentReads4ThreadsCASSpinLock),
            ("test90PercentReads4ThreadsPThreadReadWriteLock", test90PercentReads4ThreadsPThreadReadWriteLock),
        ]

            return universalTests + appleTests
        #else
            return universalTests
        #endif
    }

    var dispatchLock: DispatchLock!
    var spinLock: SpinLock!
    var casSpinLock: CASSpinLock!
    var pthreadLock: PThreadReadWriteLock!
    var queue: DispatchQueue!
    var allLocks: [Locking]!
    var locksAllowingConcurrentReads: [Locking]!

    override func setUp() {
        super.setUp()

        dispatchLock = DispatchLock()
        spinLock = SpinLock()
        casSpinLock = CASSpinLock()
        pthreadLock = PThreadReadWriteLock()

        allLocks = [dispatchLock, spinLock, casSpinLock, pthreadLock]
        locksAllowingConcurrentReads = [casSpinLock, pthreadLock]

        queue = DispatchQueue(label: "LockingTests", attributes: .concurrent)
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
                let expectation = self.expectation(description: "read \(lock)")
                queue.async {
                    lock.withReadLock {
                        timeIntervalSleep(0.1)
                        expectation.fulfill()
                    }
                }
            }

            // and make sure all 32 complete in < 3 second. If the readers
            // did not run concurrently, they would take >= 3.2 seconds
            waitForExpectationsShort()
        }
    }

    func testMultipleConcurrentWriters() {
        for lock in allLocks {
            var x = UnsafeAtomicInt32()

            // spin up 5 writers concurrently...
            for i in 0 ..< 5 {
                let expectation = self.expectation(description: "write \(lock) #\(i)")
                queue.async {
                    lock.withWriteLock {
                        // ... and make sure each runs in order by checking that
                        // no two blocks increment x at the same time
                        XCTAssertEqual(x.add(1, order: .sequentiallyConsistent), 1)
                        timeIntervalSleep(0.05)
                        XCTAssertEqual(x.subtract(1, order: .sequentiallyConsistent), 0)
                        expectation.fulfill()
                    }
                }
            }
            waitForExpectationsShort()
        }
    }

    func testSimultaneousReadersAndWriters() {
        for lock in allLocks {
            var x = UnsafeAtomicInt32()

            let startReader: (Int) -> () = { i in
                let expectation = self.expectation(description: "reader \(i)")
                self.queue.async {
                    lock.withReadLock {
                        // make sure we get the value of x either before or after
                        // the writer runs, never a partway-through value
                        let result = x.load(order: .sequentiallyConsistent)
                        XCTAssertTrue(result == 0 || result == 5)
                        expectation.fulfill()
                    }
                }
            }

            // spin up 32 readers before a writer
            for i in 0 ..< 32 {
                startReader(i)
            }
            // spin up a writer that (slowly) increments x from 0 to 5
            let expectation = self.expectation(description: "writer")
            queue.async {
                lock.withWriteLock {
                    for _ in 0 ..< 5 {
                        x.add(1, order: .sequentiallyConsistent)
                        timeIntervalSleep(0.1)
                    }
                    expectation.fulfill()
                }
            }
            // and spin up 32 more readers after
            for i in 32 ..< 64 {
                startReader(i)
            }

            waitForExpectationsShort()
        }
    }

    func measureReadLockSingleThread(_ lock: Locking, iters: Int) {
        let doNothing: () -> () = {}
        self.measure {
            for _ in 0 ..< iters {
                lock.withReadLock(doNothing)
            }
        }
    }

    func measureWriteLockSingleThread(_ lock: Locking, iters: Int) {
        let doNothing: () -> () = {}
        self.measure {
            for _ in 0 ..< iters {
                lock.withWriteLock(doNothing)
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

    func testSingleThreadPerformancePThreadReadWriteLockRead() {
        measureReadLockSingleThread(pthreadLock, iters: 250_000)
    }
    func testSingleThreadPerformancePThreadReadWriteLockWrite() {
        measureWriteLockSingleThread(pthreadLock, iters: 250_000)
    }

    #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
    class PerfTestThread: Thread {
        let iters: Int
        var lock: Locking
        let joinLock = NSConditionLock(condition: 0)

        init(lock: Locking, iters: Int) {
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
            joinLock.unlock(withCondition: 1)
        }

        func join() {
            joinLock.lock(whenCondition: 1)
            joinLock.unlock()
        }
    }

    func measureLock90PercentReadsNThreads(_ lock: Locking, iters: Int, nthreads: Int) {
        self.measure {
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

    func test90PercentReads4ThreadsGCDLock() {
        measureLock90PercentReadsNThreads(dispatchLock, iters: 5_000, nthreads: 4)
    }
    func test90PercentReads4ThreadsSpinLock() {
        measureLock90PercentReadsNThreads(spinLock, iters: 5_000, nthreads: 4)
    }
    func test90PercentReads4ThreadsCASSpinLock() {
        measureLock90PercentReadsNThreads(casSpinLock, iters: 5_000, nthreads: 4)
    }
    func test90PercentReads4ThreadsPThreadReadWriteLock() {
        measureLock90PercentReadsNThreads(pthreadLock, iters: 5_000, nthreads: 4)
    }
    #endif
}
