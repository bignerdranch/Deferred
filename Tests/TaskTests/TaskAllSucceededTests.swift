//
//  Created by Pierluigi Cifani on 29/10/2016.
//  Copyright © 2016 Big Nerd Ranch. All rights reserved.
//

import XCTest
import Dispatch

#if SWIFT_PACKAGE
    import Result
    import Deferred
    @testable import Task
    @testable import TestSupport
#else
    @testable import Deferred
#endif

class TaskAllSucceededTests: XCTestCase {
    static var allTests: [(String, (TaskAllSucceededTests) -> () throws -> Void)] {
        return [
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
        _ = semaphore.wait(timeout: .now() + .seconds(5))
        
        XCTAssert(cancellationWasPropagated)
    }
}

private enum TaskProducerError: Error {
    case unknown
    case userCancelled
}

private class TaskProducer {
    
    typealias SyncHandler = (NSError?) -> Void
    
    static func produceTask() -> Task<()> {
        return syncFolder(folderID: "0")
    }
    
    static private func sync(items: [Item]) -> [Task<()>] {
        return items.map { (item) in
            if item.isFolder {
                return self.syncFolder(folder: item as! Folder)
            } else {
                return self.sync(file: item as! File)
            }
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
        let deferred = Deferred<TaskResult<()>>()
        
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) {
            deferred.fill(with: .success())
        }
        
        return Task(future: Future(deferred), cancellation: {
            deferred.fill(with: .failure(TaskProducerError.userCancelled))
        })
    }
    
    static private func fetchFolderInfo(folderID: String) -> Task<[Item]> {
        let deferred = Deferred<TaskResult<[Item]>>()
        
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            let items = [File(), File(), File(), File(), File()]
            deferred.fill(with: .success((items)))
        }
        
        return Task(future: Future(deferred), cancellation: {
            deferred.fill(with: .failure(TaskProducerError.userCancelled))
        })
    }
}

//MARK: Model

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
        
        for _ in 0..<length {
            let randomValue = arc4random_uniform(UInt32(base.characters.count))
            randomString += "\(base[base.index(base.startIndex, offsetBy: Int(randomValue))])"
        }
        return randomString
    }
}
