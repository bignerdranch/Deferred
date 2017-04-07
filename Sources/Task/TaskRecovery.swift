//
//  TaskRecovery.swift
//  Deferred
//
//  Created by Zachary Waldowski on 10/27/15.
//  Copyright © 2015-2016 Big Nerd Ranch. Licensed under MIT.
//

#if SWIFT_PACKAGE
import Deferred
#endif
import Foundation

extension Task {
    /// Returns a `Task` containing the result of mapping `substitution` over
    /// the failed task's error.
    ///
    /// Recovering from a failed task appends a unit of progress to the root
    /// task. A root task is the earliest, or parent-most, task in a tree.
    ///
    /// The resulting task is cancellable in the same way the receiving task is.
    public func recover(upon executor: PreferredExecutor, substituting substitution: @escaping(Error) throws -> SuccessValue) -> Task<SuccessValue> {
        return recover(upon: executor as Executor, substituting: substitution)
    }
    
    /// Returns a `Task` containing the result of mapping `substitution` over
    /// the failed task's error.
    ///
    /// `recover` submits the `substitution` to the `executor` once the task
    /// fails.
    ///
    /// Recovering from a failed task appends a unit of progress to the root
    /// task. A root task is the earliest, or parent-most, task in a tree.
    ///
    /// The resulting task is cancellable in the same way the receiving task is.
    ///
    /// - see: FutureProtocol.map(upon:transform:)
    public func recover(upon executor: Executor, substituting substitution: @escaping(Error) throws -> SuccessValue) -> Task<SuccessValue> {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        let progress = extendedProgress(byUnitCount: 1)
        #endif

        let future: Future<Result> = map(upon: executor) { (result) in
            #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
            progress.becomeCurrent(withPendingUnitCount: 1)
            defer { progress.resignCurrent() }
            #endif

            return Result {
                try result.withValues(ifLeft: { try substitution($0) }, ifRight: { $0 })
            }
        }

        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        return Task<SuccessValue>(future: future, progress: progress)
        #else
        return Task<SuccessValue>(future: future, cancellation: cancel)
        #endif
    }
    
    /// Begins another task in the case of the failure of `self` by calling
    /// `restartTask` with the error.
    ///
    /// Chaining a task appends a unit of progress to the root task. A root task
    /// is the earliest, or parent-most, task in a tree of tasks.
    ///
    /// Cancelling the resulting task will attempt to cancel both the receiving
    /// task and the created task.
    public func fallback<NewTask: FutureProtocol>(upon executor: PreferredExecutor, to restartTask: @escaping(Error) -> NewTask) -> Task<SuccessValue> where NewTask.Value: Either, NewTask.Value.Left == Error, NewTask.Value.Right == SuccessValue {
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
    public func fallback<NewTask: FutureProtocol>(upon executor: Executor, to restartTask: @escaping(Error) -> NewTask) -> Task<SuccessValue> where NewTask.Value: Either, NewTask.Value.Left == Error, NewTask.Value.Right == SuccessValue {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        let progress = extendedProgress(byUnitCount: 1)
        #endif
        
        let future: Future<Result> = andThen(upon: executor) { (result) -> Task<SuccessValue> in
            #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
            progress.becomeCurrent(withPendingUnitCount: 1)
            defer { progress.resignCurrent() }
            #endif
            
            do {
                let value = try result.extract()
                return Task(success: value)
            } catch {
                return Task(restartTask(error))
            }
        }

        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        return Task<SuccessValue>(future: future, progress: progress)
        #else
        return Task<SuccessValue>(future: future, cancellation: cancel)
        #endif
    }
}
