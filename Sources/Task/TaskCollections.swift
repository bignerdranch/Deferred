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

import Dispatch

// TODO: XPLAT
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
import class Foundation.Progress

extension Collection where Iterator.Element: FutureProtocol, Iterator.Element.Value: Either, Iterator.Element.Value.Left == Error {
    /// Compose a number of tasks into a single notifier task.
    ///
    /// If any of the contained tasks fail, the returned task will be determined
    /// with that failure. Otherwise, once all operations succeed, the returned
    /// task will be determined a success.
    public func allSucceeded() -> Task<Void> {
        if isEmpty {
            return Task(success: ())
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
                result.withValues(ifLeft: { (error) in
                    _ = coalescingDeferred.fill(with: .failure(error))
                }, ifRight: { _ in })

                group.leave()
            }
        }

        group.notify(queue: queue) {
            _ = coalescingDeferred.fill(with: .success())
        }

        return Task(coalescingDeferred, progress: outerProgress)
    }
}
#endif
