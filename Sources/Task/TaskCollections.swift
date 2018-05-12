//
//  TaskCollections.swift
//  Deferred
//
//  Created by Zachary Waldowski on 11/18/15.
//  Copyright © 2015-2018 Big Nerd Ranch. Licensed under MIT.
//

#if SWIFT_PACKAGE
import Deferred
#endif

import Dispatch
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
import Foundation
#endif

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
        let group = DispatchGroup()
        let queue = DispatchQueue.global(qos: .utility)

        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        let progress = Progress(totalUnitCount: numericCast(count))
        #else
        var cancellations = Array<() -> Void>()
        cancellations.reserveCapacity(numericCast(underestimatedCount))
        #endif

        for future in self {
            #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
            if let task = future as? Task<Iterator.Element.Value.Right> {
                progress.adoptChild(task.progress, orphaned: false, pendingUnitCount: 1)
            } else {
                progress.adoptChild(.wrappingSuccess(of: future, cancellation: nil), orphaned: true, pendingUnitCount: 1)
            }
            #else
            if let task = future as? Task<Iterator.Element.Value.Right> {
                cancellations.append(task.cancel)
            }
            #endif

            group.enter()
            future.upon(queue) { result in
                result.withValues(ifLeft: { (error) in
                    _ = coalescingDeferred.fill(with: .failure(error))
                }, ifRight: { _ in })

                group.leave()
            }
        }

        group.notify(queue: queue) {
            _ = coalescingDeferred.fill(with: .success(()))
        }

        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        return Task(coalescingDeferred, progress: progress)
        #else
        let capturePromotionWorkaround = cancellations
        return Task(coalescingDeferred) {
            // https://bugs.swift.org/browse/SR-293
            for cancellation in capturePromotionWorkaround {
                cancellation()
            }
        }
        #endif
    }
}
