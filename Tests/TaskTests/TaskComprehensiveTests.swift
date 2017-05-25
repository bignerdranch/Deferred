//
//  TaskComprehensiveTests.swift
//  DeferredTests
//
//  Created by Pierluigi Cifani on 29/10/2016.
//  Copyright © 2016 Big Nerd Ranch. All rights reserved.
//
//  The following test case aggressively exercises a few features of Task and
//  Deferred. It is not a unit test, per se, but has reliably uncovered several
//  full-stack threading problems in the framework, and is included in the suite
//  as a smoke test of sorts.
//

import XCTest
import Dispatch

#if SWIFT_PACKAGE
    import Deferred
    @testable import Task
#else
    @testable import Deferred
#endif

class TaskComprehensiveTests: XCTestCase {
    static var allTests: [(String, (TaskComprehensiveTests) -> () throws -> Void)] {
        return [
            ("testThatSeveralIterationsRunCorrectly", testThatSeveralIterationsRunCorrectly),
            ("testThatCancellingATaskPropagatesTheCancellation", testThatCancellingATaskPropagatesTheCancellation),
        ]
    }

    func testThatCancellingATaskPropagatesTheCancellation() {
        let semaphore = DispatchSemaphore(value: 0)
        var cancellationWasPropagated = false

        let task1 = TaskProducer.produceTask()
        let task2 = TaskProducer.produceTask()
        let task = [task1, task2].allSucceeded()
        task.upon(DispatchQueue.any()) { result in

            defer { semaphore.signal() }

            guard let error = result.error, let taskError = error as? TaskProducerError else {
                return
            }

            cancellationWasPropagated = (taskError == TaskProducerError.userCancelled)
        }
        task.cancel()
        _ = semaphore.wait(timeout: .now() + .seconds(5))

        XCTAssert(cancellationWasPropagated)
    }

    func testThatSeveralIterationsRunCorrectly() {
        let semaphore = DispatchSemaphore(value: 0)
        let numberOfIterations = 20

        for _ in 0 ..< numberOfIterations {
            let task = TaskProducer.produceTask()
            task.upon(.any()) { _ in
                semaphore.signal()
            }
            XCTAssertEqual(semaphore.wait(timeout: .now() + .seconds(5)), .success)
        }
    }
}

// MARK: - Fixtures

private enum TaskProducerError: Error {
    case unknown
    case userCancelled
}

private final class TaskProducer {

    typealias SyncHandler = (Error?) -> Void

    static func produceTask() -> Task<Void> {
        return (0 ..< 5).map {
            syncFolder(folderID: String($0))
        }.allSucceeded()
    }

    static func sync(items: [Item]) -> [Task<()>] {
        return items.map { (item) in
            // swiftlint:disable force_cast
            if item.isFolder {
                return self.syncFolder(folder: item as! Folder)
            } else {
                return self.sync(file: item as! File)
            }
            // swiftlint:enable force_cast
        }
    }

    static private func syncFolder(folderID: String) -> Task<()> {
        return fetchFolderInfo(folderID: folderID).andThen(upon: DispatchQueue.any()) { (items) in
            return sync(items: items).allSucceeded()
        }
    }

    static private func syncFolder(folder: Folder) -> Task<()> {
        return syncFolder(folderID: folder.modelID)
    }

    static private func sync(file: File) -> Task<()> {
        let deferred = Deferred<Task<Void>.Result>()

        let queue = DispatchQueue(label: String.random())
        queue.asyncAfter(deadline: .now() + 0.3) {
            deferred.fill(with: .success(()))
        }

        return Task(future: Future(deferred), cancellation: {
            deferred.fill(with: .failure(TaskProducerError.userCancelled))
        })
    }

    static private func fetchFolderInfo(folderID: String) -> Task<[Item]> {
        let deferred = Deferred<Task<[Item]>.Result>()

        let queue = DispatchQueue(label: String.random())
        queue.asyncAfter(deadline: .now() + 0.5) {
            let items = (0 ..< 25).map { _ in File() }
            deferred.fill(with: .success((items)))
        }

        return Task(future: Future(deferred), cancellation: {
            deferred.fill(with: .failure(TaskProducerError.userCancelled))
        })
    }
}

// MARK: - Models

private protocol Item {
    var modelID: String { get }
    var isFolder: Bool { get }
    var isFile: Bool { get }
}

private struct File: Item {
    var modelID: String = String.random()
    let isFolder: Bool = false
    let isFile: Bool = true
}

private struct Folder: Item {
    var modelID: String = String.random()
    let isFolder: Bool = true
    let isFile: Bool = false
}

extension String {

    static func random(length: Int = 20) -> String {
        let base = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        var randomString: String = ""

        for _ in 0 ..< length {
            randomString.unicodeScalars.append(UnicodeScalar(base.utf16.random())!)
        }
        return randomString
    }
}
