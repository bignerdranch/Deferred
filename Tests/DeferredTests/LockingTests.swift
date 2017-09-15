//
//  LockingTests.swift
//  DeferredTests
//
//  Created by John Gallagher on 7/19/14.
//  Copyright © 2014-2016 Big Nerd Ranch. Licensed under MIT.
//

import XCTest
import Dispatch
import Foundation

@testable import Deferred
#if SWIFT_PACKAGE
import Atomics
#else
import Deferred.Atomics
#endif

class LockingTests: XCTestCase {
    static var allTests: [(String, (LockingTests) -> () throws -> Void)] {
        return [
            ("testMultipleConcurrentReaders", testMultipleConcurrentReaders),
            ("testMultipleConcurrentWriters", testMultipleConcurrentWriters),
            ("testSimultaneousReadersAndWriters", testSimultaneousReadersAndWriters),
            ("testSingleThreadPerformanceNativeLockRead", testSingleThreadPerformanceNativeLockRead),
            ("testSingleThreadPerformanceNativeLockWrite", testSingleThreadPerformanceNativeLockWrite),
            ("testSingleThreadPerformancePOSIXReadWriteLockRead", testSingleThreadPerformancePOSIXReadWriteLockRead),
            ("testSingleThreadPerformancePOSIXReadWriteLockWrite", testSingleThreadPerformancePOSIXReadWriteLockWrite),
            ("testSingleThreadPerformanceGCDLockRead", testSingleThreadPerformanceGCDLockRead),
            ("testSingleThreadPerformanceGCDLockWrite", testSingleThreadPerformanceGCDLockWrite),
            ("testSingleThreadPerformanceNSLockRead", testSingleThreadPerformanceNSLockRead),
            ("testSingleThreadPerformanceNSLockWrite", testSingleThreadPerformanceNSLockWrite),
            ("test90PercentReads4ThreadsNativeLock", test90PercentReads4ThreadsNativeLock),
            ("test90PercentReads4ThreadsPOSIXReadWriteLock", test90PercentReads4ThreadsPOSIXReadWriteLock),
            ("test90PercentReads4ThreadsGCDLock", test90PercentReads4ThreadsGCDLock),
            ("test90PercentReads4ThreadsNSLock", test90PercentReads4ThreadsNSLock)
        ]
    }

    var nativeLock: NativeLock!
    var posixLock: POSIXReadWriteLock!
    var dispatchLock: DispatchSemaphore!
    var nsLock: NSLock!

    var queue: DispatchQueue!
    var allLocks: [Locking]!
    var locksAllowingConcurrentReads: [Locking]!

    override func setUp() {
        super.setUp()

        nativeLock = NativeLock()
        posixLock = POSIXReadWriteLock()
        dispatchLock = DispatchSemaphore(value: 1)
        nsLock = NSLock()

        allLocks = [nativeLock, posixLock, dispatchLock, nsLock]
        locksAllowingConcurrentReads = [posixLock]

        queue = DispatchQueue(label: "LockingTests", attributes: .concurrent)
    }

    override func tearDown() {
        queue = nil

        allLocks = nil
        locksAllowingConcurrentReads = nil

        nativeLock = nil
        posixLock = nil
        dispatchLock = nil
        nsLock = nil

        super.tearDown()
    }

    func testMultipleConcurrentReaders() {
        for lock in locksAllowingConcurrentReads {
            // start up 32 readers that block for 0.1 seconds each...
            for _ in 0 ..< 32 {
                let expectation = self.expectation(description: "read \(lock)")
                queue.async {
                    lock.withReadLock {
                        sleep(.milliseconds(100))
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
            var x = UnsafeAtomicCounter()

            // spin up 5 writers concurrently...
            for i in 0 ..< 5 {
                let expectation = self.expectation(description: "write \(lock) #\(i)")
                queue.async {
                    lock.withWriteLock {
                        // ... and make sure each runs in order by checking that
                        // no two blocks increment x at the same time
                        XCTAssertEqual(bnr_atomic_counter_increment(&x), 1)
                        sleep(.milliseconds(50))
                        XCTAssertEqual(bnr_atomic_counter_decrement(&x), 0)
                        expectation.fulfill()
                    }
                }
            }
            waitForExpectationsShort()
        }
    }

    func testSimultaneousReadersAndWriters() {
        for lock in allLocks {
            var x = UnsafeAtomicCounter()

            let startReader: (Int) -> () = { i in
                let expectation = self.expectation(description: "reader \(i)")
                self.queue.async {
                    lock.withReadLock {
                        // make sure we get the value of x either before or after
                        // the writer runs, never a partway-through value
                        let result = bnr_atomic_counter_load(&x)
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
                        bnr_atomic_counter_increment(&x)
                        sleep(.milliseconds(100))
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

    func measureReadsSingleThread(lock: Locking, iterations: Int, file: StaticString = #file, line: Int = #line) {
        let doNothing: () -> () = {}
        func body() {
            for _ in 0 ..< iterations {
                lock.withReadLock(doNothing)
            }
        }

        #if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
            measure(body)
        #else
            measure(file: file, line: numericCast(line), block: body)
        #endif
    }

    func measureWritesSingleThread(lock: Locking, iterations: Int, file: StaticString = #file, line: Int = #line) {
        let doNothing: () -> () = {}
        func body() {
            for _ in 0 ..< iterations {
                lock.withWriteLock(doNothing)
            }
        }

        #if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
            measure(body)
        #else
            measure(file: file, line: numericCast(line), block: body)
        #endif
    }

    func testSingleThreadPerformanceNativeLockRead() {
        measureReadsSingleThread(lock: nativeLock, iterations: 250_000)
    }
    func testSingleThreadPerformanceNativeLockWrite() {
        measureWritesSingleThread(lock: nativeLock, iterations: 250_000)
    }

    func testSingleThreadPerformancePOSIXReadWriteLockRead() {
        measureReadsSingleThread(lock: posixLock, iterations: 250_000)
    }
    func testSingleThreadPerformancePOSIXReadWriteLockWrite() {
        measureWritesSingleThread(lock: posixLock, iterations: 250_000)
    }

    func testSingleThreadPerformanceGCDLockRead() {
        measureReadsSingleThread(lock: dispatchLock, iterations: 250_000)
    }
    func testSingleThreadPerformanceGCDLockWrite() {
        measureWritesSingleThread(lock: dispatchLock, iterations: 250_000)
    }

    func testSingleThreadPerformanceNSLockRead() {
        measureReadsSingleThread(lock: nsLock, iterations: 250_000)
    }
    func testSingleThreadPerformanceNSLockWrite() {
        measureWritesSingleThread(lock: nsLock, iterations: 250_000)
    }

    func measure90PercentReads(lock: Locking, iterations: Int, numberOfThreads: Int = max(ProcessInfo.processInfo.processorCount, 2), file: StaticString = #file, line: Int = #line) {
        let group = DispatchGroup()
        let queue = DispatchQueue(label: String(#function), attributes: .concurrent)
        func doNothing() {}

        func body() {
            for _ in 0 ..< numberOfThreads {
                queue.async(group: group) {
                    for i in 0 ..< iterations {
                        if (i % 10) == 0 {
                            lock.withWriteLock(doNothing)
                        } else {
                            lock.withReadLock(doNothing)
                        }
                    }
                }
            }

            group.wait()
        }

        #if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
            measure(body)
        #else
            measure(file: file, line: numericCast(line), block: body)
        #endif
    }

    func test90PercentReads4ThreadsNativeLock() {
        measure90PercentReads(lock: nativeLock, iterations: 5_000)
    }
    func test90PercentReads4ThreadsPOSIXReadWriteLock() {
        measure90PercentReads(lock: posixLock, iterations: 5_000)
    }
    func test90PercentReads4ThreadsGCDLock() {
        measure90PercentReads(lock: dispatchLock, iterations: 5_000)
    }
    func test90PercentReads4ThreadsNSLock() {
        measure90PercentReads(lock: nsLock, iterations: 5_000)
    }
}
