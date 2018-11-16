//
//  LockingTests.swift
//  DeferredTests
//
//  Created by John Gallagher on 7/19/14.
//  Copyright © 2014-2018 Big Nerd Ranch. Licensed under MIT.
//

import XCTest
import Dispatch
import Foundation

import Deferred
#if SWIFT_PACKAGE
import Atomics
#else
import Deferred.Atomics
#endif

class LockingTests: XCTestCase {
    static let allTests: [(String, (LockingTests) -> () throws -> Void)] = [
        ("testMultipleConcurrentReaders", testMultipleConcurrentReaders),
        ("testMultipleConcurrentWriters", testMultipleConcurrentWriters),
        ("testSimultaneousReadersAndWriters", testSimultaneousReadersAndWriters),
        ("testSingleThreadPerformanceRead", testSingleThreadPerformanceRead),
        ("testSingleThreadPerformanceWrite", testSingleThreadPerformanceWrite),
        ("test90PercentReads4ThreadsLock", test90PercentReads4ThreadsLock)
    ]

    class func makeLock() -> Locking {
        return NativeLock()
    }

    private(set) var lock: Locking!
    private(set) var queue: DispatchQueue!

    override func setUp() {
        super.setUp()

        lock = type(of: self).makeLock()
        queue = DispatchQueue(label: name, attributes: .concurrent)
    }

    override func tearDown() {
        queue = nil
        lock = nil

        super.tearDown()
    }

    func testMultipleConcurrentReaders() {}

    func testMultipleConcurrentWriters() {
        var counter = 0

        // spin up 5 writers concurrently...
        let allExpectations = (0 ..< 5).map { (iteration) -> XCTestExpectation in
            let expect = expectation(description: "write #\(iteration)")
            queue.async {
                self.lock.withWriteLock {
                    // ... and make sure each runs in order by checking that
                    // no two blocks increment x at the same time
                    XCTAssertEqual(bnr_atomic_fetch_add(&counter, 1), 0)
                    Thread.sleep(forTimeInterval: 0.05)
                    XCTAssertEqual(bnr_atomic_fetch_subtract(&counter, 1), 1)
                    expect.fulfill()
                }
            }
            return expect
        }

        wait(for: allExpectations, timeout: shortTimeout)
    }

    func testSimultaneousReadersAndWriters() {
        var counter = 0
        var allExpectations = [XCTestExpectation]()

        func startReader(forIteration iteration: Int) -> XCTestExpectation {
            let expect = expectation(description: "reader \(iteration)")
            queue.async {
                self.lock.withReadLock {
                    // make sure we get the value of x either before or after
                    // the writer runs, never a partway-through value
                    let result = bnr_atomic_load(&counter)
                    XCTAssertTrue(result == 0 || result == 5)
                    expect.fulfill()
                }
            }
            return expect
        }

        // spin up 32 readers before a writer
        allExpectations += (0 ..< 32).map(startReader)

        // spin up a writer that (slowly) increments x from 0 to 5
        let expectWrite = expectation(description: "writer")
        queue.async {
            self.lock.withWriteLock {
                for _ in 0 ..< 5 {
                    bnr_atomic_fetch_add(&counter, 1)
                    Thread.sleep(forTimeInterval: 0.1)
                }
                expectWrite.fulfill()
            }
        }
        allExpectations.append(expectWrite)

        // and spin up 32 more readers after
        allExpectations += (0 ..< 32).map(startReader)

        wait(for: allExpectations, timeout: longTimeout)
    }

    func testSingleThreadPerformanceRead() {
        let iterations = 250_000
        func doNothing() {}

        measure {
            for _ in 0 ..< iterations {
                lock.withReadLock(doNothing)
            }
        }
    }

    func testSingleThreadPerformanceWrite() {
        let iterations = 250_000
        func doNothing() {}

        measure {
            for _ in 0 ..< iterations {
                lock.withWriteLock(doNothing)
            }
        }
    }

    func test90PercentReads4ThreadsLock() {
        let iterations = 5000
        let numberOfThreads = max(ProcessInfo.processInfo.processorCount, 2)
        let group = DispatchGroup()
        func doNothing() {}

        measure {
            for _ in 0 ..< numberOfThreads {
                queue.async(group: group) {
                    for iteration in 0 ..< iterations {
                        if (iteration % 10) == 0 {
                            self.lock.withWriteLock(doNothing)
                        } else {
                            self.lock.withReadLock(doNothing)
                        }
                    }
                }
            }

            group.wait()
        }
    }

}

class POSIXReadWriteLockingTests: LockingTests {
    override class func makeLock() -> Locking {
        return POSIXReadWriteLock()
    }

    override func testMultipleConcurrentReaders() {
        // start up 32 readers that block for 0.1 seconds each...
        let allExpectations = (0 ..< 32).map { (iteration) -> XCTestExpectation in
            let expect = expectation(description: "read \(iteration)")
            queue.async {
                self.lock.withReadLock {
                    Thread.sleep(forTimeInterval: 0.1)
                    expect.fulfill()
                }
            }
            return expect
        }

        // and make sure all 32 complete in < 3 second. If the readers
        // did not run concurrently, they would take >= 3.2 seconds
        wait(for: allExpectations, timeout: shortTimeout)
    }

}

class DispatchSemaphoreLockingTests: LockingTests {

    override class func makeLock() -> Locking {
        return DispatchSemaphore(value: 1)
    }

}

class NSLockingTests: LockingTests {

    override class func makeLock() -> Locking {
        return NSLock()
    }

}
