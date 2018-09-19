//
//  TaskAndThen.swift
//  Deferred
//
//  Created by Zachary Waldowski on 10/27/15.
//  Copyright © 2015-2018 Big Nerd Ranch. Licensed under MIT.
//

#if SWIFT_PACKAGE
import Deferred
#endif

import Dispatch

extension TaskProtocol {
    /// Begins another task by passing the result of the task to `startNextTask`
    /// once it completes successfully.
    ///
    /// Chaining a task appends a unit of progress to the root task. A root task
    /// is the earliest, or parent-most, task in a tree of tasks.
    ///
    /// Cancelling the resulting task will attempt to cancel both the receiving
    /// task and the created task.
    public func andThen<NewTask: TaskProtocol>(upon executor: PreferredExecutor, start startNextTask: @escaping(SuccessValue) throws -> NewTask) -> Task<NewTask.SuccessValue> {
        return andThen(upon: executor as Executor, start: startNextTask)
    }

    /// Begins another task by passing the result of the task to `startNextTask`
    /// once it completes successfully.
    ///
    /// Chaining a task appends a unit of progress to the root task. A root task
    /// is the earliest, or parent-most, task in a tree of tasks.
    ///
    /// Cancelling the resulting task will attempt to cancel both the receiving
    /// task and the created task.
    ///
    /// - note: It is important to keep in mind the thread safety of the
    /// `startNextTask` closure. `andThen` submits `startNextTask` to `executor`
    /// once the task completes successfully.
    /// - see: FutureProtocol.andThen(upon:start:)
    public func andThen<NewTask: TaskProtocol>(upon executor: Executor, start startNextTask: @escaping(SuccessValue) throws -> NewTask) -> Task<NewTask.SuccessValue> {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        let progress = preparedProgressForContinuedWork()
        #else
        let cancellationToken = Deferred<Void>()
        #endif

        let future: Future = andThen(upon: executor) { (result) -> Task<NewTask.SuccessValue> in
            #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
            // We want to become the thread-local progress, but we don't
            // want to consume units; we may not attach newTask.progress to
            // the root progress until after the scope ends.
            progress.becomeCurrent(withPendingUnitCount: 1)
            defer { progress.resignCurrent() }
            #endif

            do {
                let value = try result.extract()
                // Attempt to create and wrap the next task. Task's own progress
                // wrapper logic takes over at this point.
                let newTask = try startNextTask(value)
                #if !os(macOS) && !os(iOS) && !os(tvOS) && !os(watchOS)
                cancellationToken.upon(DispatchQueue.any(), execute: newTask.cancel)
                #endif
                return Task<NewTask.SuccessValue>(newTask)
            } catch {
                return Task<NewTask.SuccessValue>(failure: error)
            }
        }

        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        return Task<NewTask.SuccessValue>(future: future, progress: progress)
        #else
        return Task<NewTask.SuccessValue>(future: future) {
            cancellationToken.fill(with: ())
        }
        #endif
    }
}
