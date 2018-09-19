//
//  TaskFallback.swift
//  Deferred
//
//  Created by Zachary Waldowski on 3/28/17.
//  Copyright © 2017-2018 Big Nerd Ranch. Licensed under MIT.
//

#if SWIFT_PACKAGE
import Deferred
#endif
import Foundation

extension TaskProtocol {
    /// Begins another task in the case of the failure of `self` by calling
    /// `restartTask` with the error.
    ///
    /// Chaining a task appends a unit of progress to the root task. A root task
    /// is the earliest, or parent-most, task in a tree of tasks.
    ///
    /// Cancelling the resulting task will attempt to cancel both the receiving
    /// task and the created task.
    public func fallback<NewTask: TaskProtocol>(upon executor: PreferredExecutor, to restartTask: @escaping(Error) throws -> NewTask) -> Task<SuccessValue> where NewTask.SuccessValue == SuccessValue {
        return fallback(upon: executor as Executor, to: restartTask)
    }

    /// Begins another task in the case of the failure of `self` by calling
    /// `restartTask` with the error.
    ///
    /// Chaining a task appends a unit of progress to the root task. A root task
    /// is the earliest, or parent-most, task in a tree of tasks.
    ///
    /// Cancelling the resulting task will attempt to cancel both the receiving
    /// task and the created task.
    ///
    /// - note: It is important to keep in mind the thread safety of the
    /// `restartTask` closure. `fallback` submits `restartTask` to `executor`
    /// once the task fails.
    /// - see: FutureProtocol.andThen(upon:start:)
    public func fallback<NewTask: TaskProtocol>(upon executor: Executor, to restartTask: @escaping(Error) throws -> NewTask) -> Task<SuccessValue> where NewTask.SuccessValue == SuccessValue {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        let progress = preparedProgressForContinuedWork()
        #else
        let cancellationToken = Deferred<Void>()
        #endif

        let future: Future = andThen(upon: executor) { (result) -> Task<SuccessValue> in
            #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
            progress.becomeCurrent(withPendingUnitCount: 1)
            defer { progress.resignCurrent() }
            #endif

            do {
                let value = try result.extract()
                return Task(success: value)
            } catch {
                do {
                    let newTask = try restartTask(error)
                    #if !os(macOS) && !os(iOS) && !os(tvOS) && !os(watchOS)
                    cancellationToken.upon(execute: newTask.cancel)
                    #endif
                    return Task(newTask)
                } catch {
                    return Task(failure: error)
                }
            }
        }

        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        return Task<SuccessValue>(future, progress: progress)
        #else
        return Task<SuccessValue>(future) {
            cancellationToken.fill(with: ())
        }
        #endif
    }

    /// Begin a task immediately by calling `startTask`, then if it fails retry
    /// up to the `numberOfAttempts`.
    public static func `repeat`(
        upon preferredExecutor: PreferredExecutor,
        count numberOfAttempts: Int = 3,
        continuingIf shouldRetry: @escaping(Error) -> Bool = { _ in return true },
        to startTask: @escaping() throws -> Task<SuccessValue>
    ) -> Task<SuccessValue> {
        return self.repeat(upon: preferredExecutor as Executor, count: numberOfAttempts, continuingIf: shouldRetry, to: startTask)
    }

    /// Begin a task immediately by calling `startTask`, then if it fails retry
    /// by calling `startTask` up to the `numberOfAttempts`.
    ///
    /// If `numberOfAttempts` is less than 1, `startTask` will still be invoked
    /// regardless.
    ///
    /// If provided, `shouldRetry` will be submitted to the `executor` to check
    /// whether the work can be retried for a given failure. Without a retry
    /// predicate, the attempt will always continue.
    ///
    /// - note: It is important to keep in mind the thread safety of the
    /// `startTask` closure. It is initially called in the current execution
    /// context, then submitted to `executor` for any failures.
    public static func `repeat`(
        upon executor: Executor,
        count numberOfAttempts: Int = 3,
        continuingIf shouldRetry: @escaping(Error) -> Bool = { _ in return true },
        to startTask: @escaping() throws -> Task<SuccessValue>
    ) -> Task<SuccessValue> {
        var lastFailedTask: Task<SuccessValue>
        do {
            lastFailedTask = try startTask()
        } catch {
            return Task(failure: error)
        }

        for _ in 0 ..< max(numberOfAttempts, 0) {
            lastFailedTask = lastFailedTask.fallback(upon: executor) { (error) -> Task<SuccessValue> in
                guard shouldRetry(error) else {
                    throw error
                }

                return try startTask()
            }
        }

        return lastFailedTask
    }
}
