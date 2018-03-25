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
        ("testReflectionWhenLocked", testReflectionWhenLocked)
    ]

    var protected: Protected<(Date?, [Int])>!
    var queue: DispatchQueue!

    override func setUp() {
        super.setUp()

        protected = Protected(initialValue: (nil, []))
        queue = DispatchQueue(label: "ProtectedTests", attributes: .concurrent)
    }

    override func tearDown() {
        queue = nil
        protected = nil

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

        shortWait(for: allExpectations)
    }

    func testDebugDescription() {
        let protected = Protected<Int>(initialValue: 42)
        XCTAssertEqual("\(protected)", "Protected(42)")
    }

    func testDebugDescriptionWhenLocked() {
        let customLock = NSLock()
        let protected = Protected<Int>(initialValue: 42, lock: customLock)

        customLock.lock()
        defer { customLock.unlock() }

        XCTAssertEqual("\(protected)", "Protected(locked)")
    }

    func testReflection() {
        let protected = Protected<Int>(initialValue: 42)

        let magicMirror = Mirror(reflecting: protected)
        XCTAssertEqual(magicMirror.displayStyle, .optional)
        XCTAssertNil(magicMirror.superclassMirror)
        XCTAssertEqual(magicMirror.descendant(0) as? Int, 42)
    }

    func testReflectionWhenLocked() {
        let customLock = NSLock()
        let protected = Protected<Int>(initialValue: 42, lock: customLock)

        customLock.lock()
        defer { customLock.unlock() }

        let magicMirror = Mirror(reflecting: protected)
        XCTAssertEqual(magicMirror.displayStyle, .optional)
        XCTAssertNil(magicMirror.superclassMirror)
        XCTAssertEqual(magicMirror.descendant("isLocked") as? Bool, true)
    }

}
