//
//  TaskCollections.swift
//  Deferred
//
//  Created by Zachary Waldowski on 11/18/15.
//  Copyright © 2015-2016 Big Nerd Ranch. Licensed under MIT.
//

#if SWIFT_PACKAGE
import Deferred
import Result
#endif
import Foundation

extension Collection where Iterator.Element: FutureProtocol, Iterator.Element.Value: ResultType {
    /// Compose a number of tasks into a single notifier task.
    ///
    /// If any of the contained tasks fail, the returned task will be determined
    /// with that failure. Otherwise, once all operations succeed, the returned
    /// task will be determined a success.
    public var joinedTasks: Task<Void> {
        if isEmpty {
            return Task(value: ())
        }

        let coalescingDeferred = Deferred<Task<Void>.Result>()
        let outerProgress = Progress(parent: nil, userInfo: nil)
        outerProgress.totalUnitCount = numericCast(count)
        let group = DispatchGroup()
        let queue = DispatchQueue.global(qos: .utility)

        for task in self {
            let innerProgress = Progress.wrapped(task, cancellation: nil)
            outerProgress.adoptChild(innerProgress, orphaned: true, pendingUnitCount: 1)

            group.enter()
            task.upon(queue) { result in
                result.withValues(ifSuccess: { _ in }, ifFailure: { error in
                    _ = coalescingDeferred.fill(with: .failure(error))
                })

                group.leave()
            }
        }

        group.notify(queue: queue) {
            _ = coalescingDeferred.fill(with: .success())
        }

        return Task(coalescingDeferred, progress: outerProgress)
    }
}
