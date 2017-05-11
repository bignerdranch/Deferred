//
//  TaskMap.swift
//  Deferred
//
//  Created by Zachary Waldowski on 10/27/15.
//  Copyright © 2015-2016 Big Nerd Ranch. Licensed under MIT.
//

#if SWIFT_PACKAGE
import Deferred
#endif

extension Task {
    /// Returns a `Task` containing the result of mapping `transform` over the
    /// successful task's value.
    ///
    /// Mapping a task appends a unit of progress to the root task. A root task
    /// is the earliest, or parent-most, task in a tree of tasks.
    ///
    /// The resulting task is cancellable in the same way the receiving task is.
    public func map<NewSuccessValue>(upon queue: PreferredExecutor, transform: @escaping(SuccessValue) throws -> NewSuccessValue) -> Task<NewSuccessValue> {
        return map(upon: queue as Executor, transform: transform)
    }

    /// Returns a `Task` containing the result of mapping `transform` over the
    /// successful task's value.
    ///
    /// The `transform` is submitted to the `executor` once the task completes.
    ///
    /// Mapping a task appends a unit of progress to the root task. A root task
    /// is the earliest, or parent-most, task in a tree of tasks.
    ///
    /// The resulting task is cancellable in the same way the receiving task is.
    ///
    /// - see: FutureProtocol.map(upon:transform:)
    public func map<NewSuccessValue>(upon executor: Executor, transform: @escaping(SuccessValue) throws -> NewSuccessValue) -> Task<NewSuccessValue> {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        let progress = extendedProgress(byUnitCount: 1)
        #endif

        let future: Future<Task<NewSuccessValue>.Result> = map(upon: executor) { (result) in
            #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
            progress.becomeCurrent(withPendingUnitCount: 1)
            defer { progress.resignCurrent() }
            #endif

            return Task<NewSuccessValue>.Result {
                try transform(result.extract())
            }
        }

        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        return Task<NewSuccessValue>(future: future, progress: progress)
        #else
        return Task<NewSuccessValue>(future: future, cancellation: cancel)
        #endif
    }
}
