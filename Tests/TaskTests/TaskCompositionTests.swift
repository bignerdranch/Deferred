//
//  TaskCompositionTests.swift
//  Deferred
//
//  Created by Zachary Waldowski on 4/12/20.
//  Copyright © 2020 Big Nerd Ranch. Licensed under MIT.
//

import XCTest

#if SWIFT_PACKAGE
import Deferred
import Task
#else
import Deferred
#endif

class TaskCompositionTests: CustomExecutorTestCase {
    struct Type1 {}
    struct Type2 {}
    struct Type3 {}
    struct Type4 {}
    struct Type5 {}
    struct Type6 {}
    struct Type7 {}
    struct Type8 {}

    func testAndSuccess() {
        let toBeCombined1 = Task<Type1>.Promise()
        let toBeCombined2 = Task<Type2>.Promise()
        let combined = toBeCombined1.andSuccess(of: toBeCombined2)

        let expect = expectation(description: "Combined task delivered its result once")
        combined.uponSuccess { _ in
            expect.fulfill()
        }

        XCTAssertFalse(combined.isFilled)
        toBeCombined1.succeed(with: Type1())

        XCTAssertFalse(combined.isFilled)
        toBeCombined2.succeed(with: Type2())

        wait(for: [ expect ], timeout: shortTimeout)
        XCTAssertTrue(combined.isFilled)
    }

    func testAndSuccess3() {
        let toBeCombined1 = Task<Type1>.Promise()
        let toBeCombined2 = Task<Type2>.Promise()
        let toBeCombined3 = Task<Type3>.Promise()
        let combined = toBeCombined1.andSuccess(of:
            toBeCombined2, toBeCombined3)

        let expect = expectation(description: "Combined task delivered its result once")
        combined.uponSuccess { _ in
            expect.fulfill()
        }

        XCTAssertFalse(combined.isFilled)
        toBeCombined1.succeed(with: Type1())

        XCTAssertFalse(combined.isFilled)
        toBeCombined2.succeed(with: Type2())

        XCTAssertFalse(combined.isFilled)
        toBeCombined3.succeed(with: Type3())

        wait(for: [ expect ], timeout: shortTimeout)
        XCTAssertTrue(combined.isFilled)
    }

    func testAndSuccess4() {
        let toBeCombined1 = Task<Type1>.Promise()
        let toBeCombined2 = Task<Type2>.Promise()
        let toBeCombined3 = Task<Type3>.Promise()
        let toBeCombined4 = Task<Type4>.Promise()
        let combined = toBeCombined1.andSuccess(of:
            toBeCombined2, toBeCombined3, toBeCombined4)

        let expect = expectation(description: "Combined task delivered its result once")
        combined.uponSuccess { _ in
            expect.fulfill()
        }

        XCTAssertFalse(combined.isFilled)
        toBeCombined1.succeed(with: Type1())

        XCTAssertFalse(combined.isFilled)
        toBeCombined2.succeed(with: Type2())

        XCTAssertFalse(combined.isFilled)
        toBeCombined3.succeed(with: Type3())

        XCTAssertFalse(combined.isFilled)
        toBeCombined4.succeed(with: Type4())

        wait(for: [ expect ], timeout: shortTimeout)
        XCTAssertTrue(combined.isFilled)
    }

    func testAndSuccess5() {
        let toBeCombined1 = Task<Type1>.Promise()
        let toBeCombined2 = Task<Type2>.Promise()
        let toBeCombined3 = Task<Type3>.Promise()
        let toBeCombined4 = Task<Type4>.Promise()
        let toBeCombined5 = Task<Type5>.Promise()
        let combined = toBeCombined1.andSuccess(of:
            toBeCombined2, toBeCombined3, toBeCombined4,
            toBeCombined5)

        let expect = expectation(description: "Combined task delivered its result once")
        combined.uponSuccess { _ in
            expect.fulfill()
        }

        XCTAssertFalse(combined.isFilled)
        toBeCombined1.succeed(with: Type1())

        XCTAssertFalse(combined.isFilled)
        toBeCombined2.succeed(with: Type2())

        XCTAssertFalse(combined.isFilled)
        toBeCombined3.succeed(with: Type3())

        XCTAssertFalse(combined.isFilled)
        toBeCombined4.succeed(with: Type4())

        XCTAssertFalse(combined.isFilled)
        toBeCombined5.succeed(with: Type5())

        wait(for: [ expect ], timeout: shortTimeout)
        XCTAssertTrue(combined.isFilled)
    }

    func testAndSuccess6() {
        let toBeCombined1 = Task<Type1>.Promise()
        let toBeCombined2 = Task<Type2>.Promise()
        let toBeCombined3 = Task<Type3>.Promise()
        let toBeCombined4 = Task<Type4>.Promise()
        let toBeCombined5 = Task<Type5>.Promise()
        let toBeCombined6 = Task<Type6>.Promise()
        let combined = toBeCombined1.andSuccess(of:
            toBeCombined2, toBeCombined3, toBeCombined4,
            toBeCombined5, toBeCombined6)

        let expect = expectation(description: "Combined task delivered its result once")
        combined.uponSuccess { _ in
            expect.fulfill()
        }

        XCTAssertFalse(combined.isFilled)
        toBeCombined1.succeed(with: Type1())

        XCTAssertFalse(combined.isFilled)
        toBeCombined2.succeed(with: Type2())

        XCTAssertFalse(combined.isFilled)
        toBeCombined3.succeed(with: Type3())

        XCTAssertFalse(combined.isFilled)
        toBeCombined4.succeed(with: Type4())

        XCTAssertFalse(combined.isFilled)
        toBeCombined5.succeed(with: Type5())

        XCTAssertFalse(combined.isFilled)
        toBeCombined6.succeed(with: Type6())

        wait(for: [ expect ], timeout: shortTimeout)
        XCTAssertTrue(combined.isFilled)
    }

    func testAndSuccess7() {
        let toBeCombined1 = Task<Type1>.Promise()
        let toBeCombined2 = Task<Type2>.Promise()
        let toBeCombined3 = Task<Type3>.Promise()
        let toBeCombined4 = Task<Type4>.Promise()
        let toBeCombined5 = Task<Type5>.Promise()
        let toBeCombined6 = Task<Type6>.Promise()
        let toBeCombined7 = Task<Type7>.Promise()
        let combined = toBeCombined1.andSuccess(of:
            toBeCombined2, toBeCombined3, toBeCombined4,
            toBeCombined5, toBeCombined6, toBeCombined7)

        let expect = expectation(description: "Combined task delivered its result once")
        combined.uponSuccess { _ in
            expect.fulfill()
        }

        XCTAssertFalse(combined.isFilled)
        toBeCombined1.succeed(with: Type1())

        XCTAssertFalse(combined.isFilled)
        toBeCombined2.succeed(with: Type2())

        XCTAssertFalse(combined.isFilled)
        toBeCombined3.succeed(with: Type3())

        XCTAssertFalse(combined.isFilled)
        toBeCombined4.succeed(with: Type4())

        XCTAssertFalse(combined.isFilled)
        toBeCombined5.succeed(with: Type5())

        XCTAssertFalse(combined.isFilled)
        toBeCombined6.succeed(with: Type6())

        XCTAssertFalse(combined.isFilled)
        toBeCombined7.succeed(with: Type7())

        wait(for: [ expect ], timeout: shortTimeout)
        XCTAssertTrue(combined.isFilled)
    }

    func testAndSuccess8() {
        let toBeCombined1 = Task<Type1>.Promise()
        let toBeCombined2 = Task<Type2>.Promise()
        let toBeCombined3 = Task<Type3>.Promise()
        let toBeCombined4 = Task<Type4>.Promise()
        let toBeCombined5 = Task<Type5>.Promise()
        let toBeCombined6 = Task<Type6>.Promise()
        let toBeCombined7 = Task<Type7>.Promise()
        let toBeCombined8 = Task<Type8>.Promise()
        let combined = toBeCombined1.andSuccess(of:
            toBeCombined2, toBeCombined3, toBeCombined4,
            toBeCombined5, toBeCombined6, toBeCombined7,
            toBeCombined8)

        let expect = expectation(description: "Combined task delivered its result once")
        combined.uponSuccess { _ in
            expect.fulfill()
        }

        XCTAssertFalse(combined.isFilled)
        toBeCombined1.succeed(with: Type1())

        XCTAssertFalse(combined.isFilled)
        toBeCombined2.succeed(with: Type2())

        XCTAssertFalse(combined.isFilled)
        toBeCombined3.succeed(with: Type3())

        XCTAssertFalse(combined.isFilled)
        toBeCombined4.succeed(with: Type4())

        XCTAssertFalse(combined.isFilled)
        toBeCombined5.succeed(with: Type5())

        XCTAssertFalse(combined.isFilled)
        toBeCombined6.succeed(with: Type6())

        XCTAssertFalse(combined.isFilled)
        toBeCombined7.succeed(with: Type7())

        XCTAssertFalse(combined.isFilled)
        toBeCombined8.succeed(with: Type8())

        wait(for: [ expect ], timeout: shortTimeout)
        XCTAssertTrue(combined.isFilled)
    }

    func testAndSuccessFailure() {
        let toBeCombined1 = Task<Type1>.Promise()
        let toBeCombined2 = Task<Type2>.Promise()
        let combined = toBeCombined1.andSuccess(of: toBeCombined2)

        let expect = expectation(description: "Combined task delivered a failure once")
        combined.uponFailure { error in
            expect.fulfill()
            XCTAssertEqual(error as? TestError, .fourth)
        }

        XCTAssertFalse(combined.isFilled)
        toBeCombined2.fail(with: TestError.fourth)

        wait(for: [ expect ], timeout: shortTimeout)
        XCTAssertTrue(combined.isFilled)
    }
}
