//
//  LinuxMain.swift
//  DeferredTests
//
//  Created by Zachary Waldowski on 9/21/16.
//  Copyright © 2016 Big Nerd Ranch. Licensed under MIT.
//

import XCTest
@testable import DeferredTests
@testable import ResultTests
@testable import TaskTests

XCTMain([
    testCase(DeferredTests.allTests),
    testCase(ExistentialFutureTests.allTests),
    testCase(FutureCustomExecutorTests.allTests),
    testCase(FutureIgnoreTests.allTests),
    testCase(FutureTests.allTests),
    testCase(LockingTests.allTests),
    testCase(ProtectedTests.allTests),

    testCase(ResultRecoveryTests.allTests),
    testCase(TaskResultTests.allTests),
    testCase(VoidResultTests.allTests),

    testCase(TaskGroupTests.allTests),
    testCase(TaskTests.allTests),
    testCase(TaskWorkItemTests.allTests),
])
