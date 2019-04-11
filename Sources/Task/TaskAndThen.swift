//
//  TaskAndThen.swift
//  Deferred
//
//  Created by Zachary Waldowski on 10/27/15.
//  Copyright © 2015-2019 Big Nerd Ranch. Licensed under MIT.
//

#if SWIFT_PACKAGE
import Deferred
#endif
import Dispatch

extension TaskProtocol {
    /// Begins another task by passing the result of the task to `startNextTask`
    /// once it completes successfully.
    ///
    /// On Apple platforms, chaining a task contributes a unit of progress to
    /// the root task. A root task is the earliest task in a chain of tasks. If
    /// `startNextTask` runs and returns a task that itself reports progress,
    /// that progress will also contribute to the chain's overall progress.
    ///
    /// Cancelling the resulting task will attempt to cancel both the receiving
    /// task and the created task.
    public func andThen<NewTask: TaskProtocol>(upon executor: PreferredExecutor, start startNextTask: @escaping(Success) throws -> NewTask) -> Task<NewTask.Success> {
        return andThen(upon: executor as Executor, start: startNextTask)
    }

    /// Begins another task by passing the result of the task to `startNextTask`
    /// once it completes successfully.
    ///
    /// On Apple platforms, chaining a task contributes a unit of progress to
    /// the root task. A root task is the earliest task in a chain of tasks. If
    /// `startNextTask` runs and returns a task that itself reports progress,
    /// that progress will also contribute to the chain's overall progress.
    ///
    /// Cancelling the resulting task will attempt to cancel both the receiving
    /// task and the created task.
    ///
    /// - note: It is important to keep in mind the thread safety of the
    /// `startNextTask` closure. `andThen` submits `startNextTask` to `executor`
    /// once the task completes successfully.
    /// - see: FutureProtocol.andThen(upon:start:)
    public func andThen<NewTask: TaskProtocol>(upon executor: Executor, start startNextTask: @escaping(Success) throws -> NewTask) -> Task<NewTask.Success> {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        let chain = TaskChain(andThenFrom: self)
        #else
        let cancellationToken = Deferred<Void>()
        #endif

        let future: Future<NewTask.Value> = andThen(upon: executor) { (result) -> Future<NewTask.Value> in
            #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
            chain.beginAndThen()
            #endif

            do {
                let value = try result.get()
                let newTask = try startNextTask(value)
                #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
                chain.commitAndThen(with: newTask)
                #else
                cancellationToken.upon(DispatchQueue.any(), execute: newTask.cancel)
                #endif
                return Future(newTask)
            } catch {
                #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
                chain.flushAndThen()
                #endif
                return Future(failure: error)
            }
        }

        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        return Task<NewTask.Success>(future, progress: chain.effectiveProgress)
        #else
        return Task<NewTask.Success>(future) {
            cancellationToken.fill(with: ())
        }
        #endif
    }
}
