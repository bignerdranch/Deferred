//
//  ProtectedTests.swift
//  DeferredTests
//
//  Created by John Gallagher on 7/19/14.
//  Copyright © 2014-2018 Big Nerd Ranch. Licensed under MIT.
//

import XCTest
import Dispatch
import Foundation

@testable import Deferred

class ProtectedTests: XCTestCase {
    static var allTests: [(String, (ProtectedTests) -> () throws -> Void)] {
        return [
            ("testConcurrentReadingWriting", testConcurrentReadingWriting),
            ("testDebugDescription", testDebugDescription),
            ("testDebugDescriptionWhenLocked", testDebugDescriptionWhenLocked),
            ("testReflection", testReflection),
            ("testReflectionWhenLocked", testReflectionWhenLocked)
        ]
    }

    var protected: Protected<(Date?, [Int])>!
    var queue: DispatchQueue!

    override func setUp() {
        super.setUp()

        protected = Protected(initialValue: (nil, []))
        queue = DispatchQueue(label: "ProtectedTests", attributes: .concurrent)
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testConcurrentReadingWriting() {
        var lastWriterDate: Date?

        let startReader: (Int) -> () = { iteration in
            let expectation = self.expectation(description: "reader \(iteration)")
            self.queue.async {
                self.protected.withReadLock { (arg) -> () in
                    let (date, items) = arg
                    if items.isEmpty && date == nil {
                        // OK - we're before the writer has added items
                    } else if items.count == 5 && date == lastWriterDate {
                        // OK - we're after the writer has added items
                    } else {
                        XCTFail("invalid count (\(items.count)) or date (\(String(describing: date)))")
                    }
                }
                expectation.fulfill()
            }
        }

        for i in 0 ..< 64 {
            startReader(i)
        }
        let expectation = self.expectation(description: "writer")
        self.queue.async {
            self.protected.withWriteLock { dateItemsTuple -> () in
                for i in 0 ..< 5 {
                    dateItemsTuple.0 = Date()
                    dateItemsTuple.1.append(i)
                    sleep(.milliseconds(100))
                }
                lastWriterDate = dateItemsTuple.0
            }
            expectation.fulfill()
        }
        for i in 64 ..< 128 {
            startReader(i)
        }

        waitForExpectationsShort()
    }

    func testDebugDescription() {
        let protected = Protected<Int>(initialValue: 42)
        XCTAssertEqual("\(protected)", "Protected<Int>(42)")
    }

    func testDebugDescriptionWhenLocked() {
        let customLock = NSLock()
        let protected = Protected<Int>(initialValue: 42, lock: customLock)

        customLock.lock()
        defer { customLock.unlock() }

        XCTAssertEqual("\(protected)", "Protected<Int> (lock contended)")
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
        XCTAssertEqual(magicMirror.displayStyle, .tuple)
        XCTAssertNil(magicMirror.superclassMirror)
        XCTAssertEqual(magicMirror.descendant("lockContended") as? Bool, true)
    }
}
