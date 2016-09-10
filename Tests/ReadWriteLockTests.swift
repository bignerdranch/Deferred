//
//  ReadWriteLockTests.swift
//  ReadWriteLockTests
//
//  Created by John Gallagher on 7/19/14.
//  Copyright © 2014-2015 Big Nerd Ranch. Licensed under MIT.
//

import XCTest
import Deferred
#if SWIFT_PACKAGE
import AtomicSwift
#endif

func timeIntervalSleep(_ duration: TimeInterval) {
    usleep(useconds_t(duration * TimeInterval(USEC_PER_SEC)))
}

class PerfTestThread: Thread {
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
        joinLock.unlock(withCondition: 1)
    }

    func join() {
        joinLock.lock(whenCondition: 1)
        joinLock.unlock()
    }
}

class ReadWriteLockTests: XCTestCase {
    var dispatchLock: DispatchLock!
    var spinLock: SpinLock!
    var casSpinLock: CASSpinLock!
    var pthreadLock: PThreadReadWriteLock!
    var queue: DispatchQueue!
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

        queue = DispatchQueue(label: "ReadWriteLockTests", attributes: .concurrent)
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
            var x: Int32 = 0

            // spin up 5 writers concurrently...
            for i in 0 ..< 5 {
                let expectation = self.expectation(description: "write \(lock) #\(i)")
                queue.async {
                    lock.withWriteLock {
                        // ... and make sure each runs in order by checking that
                        // no two blocks increment x at the same time
                        XCTAssertEqual(OSAtomicIncrement32Barrier(&x), 1)
                        timeIntervalSleep(0.05)
                        XCTAssertEqual(OSAtomicDecrement32Barrier(&x), 0)
                        expectation.fulfill()
                    }
                }
            }
            waitForExpectationsShort()
        }
    }

    func testSimultaneousReadersAndWriters() {
        for lock in allLocks {
            var x: Int32 = 0

            let startReader: (Int) -> () = { i in
                let expectation = self.expectation(description: "reader \(i)")
                self.queue.async {
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
            let expectation = self.expectation(description: "writer")
            queue.async {
                lock.withWriteLock {
                    for _ in 0 ..< 5 {
                        OSAtomicIncrement32Barrier(&x)
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

    func measureReadLockSingleThread(_ lock: ReadWriteLock, iters: Int) {
        let doNothing: () -> () = {}
        self.measure {
            for _ in 0 ..< iters {
                lock.withReadLock(doNothing)
            }
        }
    }

    func measureWriteLockSingleThread(_ lock: ReadWriteLock, iters: Int) {
        let doNothing: () -> () = {}
        self.measure {
            for _ in 0 ..< iters {
                lock.withWriteLock(doNothing)
            }
        }
    }

    func measureLock90PercentReadsNThreads(_ lock: ReadWriteLock, iters: Int, nthreads: Int) {
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
