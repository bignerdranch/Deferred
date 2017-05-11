//
//  LinuxMain.swift
//  DeferredTests
//
//  Created by Zachary Waldowski on 9/21/16.
//  Copyright © 2016 Big Nerd Ranch. Licensed under MIT.
//

import XCTest
@testable import DeferredTests
@testable import TaskTests

XCTMain([
    testCase(DeferredTests.allTests),
    testCase(ExistentialFutureTests.allTests),
    testCase(FutureCustomExecutorTests.allTests),
    testCase(FutureIgnoreTests.allTests),
    testCase(FutureTests.allTests),
    testCase(LockingTests.allTests),
    testCase(ProtectedTests.allTests),
    testCase(SwiftBugTests.allTests),

    testCase(ResultRecoveryTests.allTests),
    testCase(TaskComprehensiveTests.allTests),
    testCase(TaskGroupTests.allTests),
    testCase(TaskResultTests.allTests),
    testCase(TaskTests.allTests),
    testCase(TaskWorkItemTests.allTests),
    testCase(VoidResultTests.allTests)
])
