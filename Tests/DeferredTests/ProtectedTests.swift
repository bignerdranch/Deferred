//
//  ProtectedTests.swift
//  DeferredTests
//
//  Created by John Gallagher on 7/19/14.
//  Copyright © 2014-2018 Big Nerd Ranch. Licensed under MIT.
//

import XCTest
import Dispatch
import Deferred

class ProtectedTests: XCTestCase {
    static let allTests: [(String, (ProtectedTests) -> () throws -> Void)] = [
        ("testConcurrentReadingWriting", testConcurrentReadingWriting),
        ("testDebugDescription", testDebugDescription),
        ("testDebugDescriptionWhenLocked", testDebugDescriptionWhenLocked),
        ("testReflection", testReflection),
        ("testReflectionWhenLocked", testReflectionWhenLocked),
        ("testPerformanceSingleThreadRead", testPerformanceSingleThreadRead),
        ("testPerformanceSingleThreadWrite", testPerformanceSingleThreadWrite),
        ("testPerformance90PercentReads4ThreadsLock", testPerformance90PercentReads4ThreadsLock)
    ]

    func makeLock() -> Locking {
        return NativeLock()
    }

    var lock: Locking!
    var protected: Protected<(Date?, [Int])>!
    let queue = DispatchQueue(label: "ProtectedTests", attributes: .concurrent)

    override func setUp() {
        super.setUp()

        lock = makeLock()
        protected = Protected(initialValue: (nil, []), lock: lock)
    }

    override func tearDown() {
        protected = nil
        lock = nil

        super.tearDown()
    }

    func testConcurrentReadingWriting() {
        var lastWriterDate: Date?
        var allExpectations = [XCTestExpectation]()

        func startReader(forIteration iteration: Int) -> XCTestExpectation {
            let expect = expectation(description: "reader \(iteration)")
            queue.async {
                self.protected.withReadLock { (arg) in
                    let (date, items) = arg
                    if items.isEmpty && date == nil {
                        // OK - we're before the writer has added items
                    } else if items.count == 5 && date == lastWriterDate {
                        // OK - we're after the writer has added items
                    } else {
                        XCTFail("invalid count (\(items.count)) or date (\(String(describing: date)))")
                    }
                }
                expect.fulfill()
            }
            return expect
        }

        allExpectations += (0 ..< 64).map(startReader)

        let expectWrite = expectation(description: "writer")
        queue.async {
            self.protected.withWriteLock { dateItemsTuple -> Void in
                for iteration in 0 ..< 5 {
                    dateItemsTuple.0 = Date()
                    dateItemsTuple.1.append(iteration)
                    Thread.sleep(forTimeInterval: 0.1)
                }
                lastWriterDate = dateItemsTuple.0
            }
            expectWrite.fulfill()
        }
        allExpectations.append(expectWrite)

        allExpectations += (64 ..< 128).map(startReader)

        wait(for: allExpectations, timeout: longTimeout)
    }

    func testDebugDescription() {
        let protected = Protected<Int>(initialValue: 42, lock: lock)
        XCTAssertEqual("\(protected)", "Protected(42)")
    }

    func testDebugDescriptionWhenLocked() {
        let protected = Protected<Int>(initialValue: 42, lock: lock)

        lock.withWriteLock {
            XCTAssertEqual("\(protected)", "Protected(locked)")
        }
    }

    func testReflection() {
        let protected = Protected<Int>(initialValue: 42, lock: lock)

        let magicMirror = Mirror(reflecting: protected)
        XCTAssertEqual(magicMirror.displayStyle, .optional)
        XCTAssertNil(magicMirror.superclassMirror)
        XCTAssertEqual(magicMirror.descendant(0) as? Int, 42)
    }

    func testReflectionWhenLocked() {
        let protected = Protected<Int>(initialValue: 42, lock: lock)

        lock.withWriteLock {
            let magicMirror = Mirror(reflecting: protected)
            XCTAssertEqual(magicMirror.displayStyle, .optional)
            XCTAssertNil(magicMirror.superclassMirror)
            XCTAssertEqual(magicMirror.descendant("isLocked") as? Bool, true)
        }
    }

    func testPerformanceSingleThreadRead() {
        let iterations = 250_000
        func doNothing() {}

        measure {
            for _ in 0 ..< iterations {
                lock.withReadLock(doNothing)
            }
        }
    }

    func testPerformanceSingleThreadWrite() {
        let iterations = 250_000
        func doNothing() {}

        measure {
            for _ in 0 ..< iterations {
                lock.withWriteLock(doNothing)
            }
        }
    }

    func testPerformance90PercentReads4ThreadsLock() {
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

class ProtectedTestsUsingDispatchSemaphore: ProtectedTests {
    override func makeLock() -> Locking {
        return DispatchSemaphore(value: 1)
    }
}

class ProtectedTestsUsingPOSIXReadWriteLock: ProtectedTests {
    override func makeLock() -> Locking {
        return POSIXReadWriteLock()
    }
}

class ProtectedTestsUsingNSLock: ProtectedTests {
    override func makeLock() -> Locking {
        return NSLock()
    }
}
