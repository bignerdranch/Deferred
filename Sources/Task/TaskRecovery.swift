//
//  TaskRecovery.swift
//  Deferred
//
//  Created by Zachary Waldowski on 10/27/15.
//  Copyright © 2015-2019 Big Nerd Ranch. Licensed under MIT.
//

#if SWIFT_PACKAGE
import Deferred
#endif

extension TaskProtocol {
    /// Returns a `Task` containing the result of mapping `substitution` over
    /// the failed task's error.
    ///
    /// On Apple platforms, recovering from a failed task reports its progress
    /// to the root task. A root task is the earliest task in a chain of tasks.
    /// During execution of `transform`, an additional progress object created
    /// using the current parent will also contribute to the chain's progress.
    ///
    /// The resulting task is cancellable in the same way the receiving task is.
    public func recover(upon executor: PreferredExecutor, substituting substitution: @escaping(Failure) throws -> Success) -> Task<Success> {
        return recover(upon: executor as Executor, substituting: substitution)
    }

    /// Returns a `Task` containing the result of mapping `substitution` over
    /// the failed task's error.
    ///
    /// `recover` submits the `substitution` to the `executor` once the task
    /// fails.
    ///
    /// On Apple platforms, recovering from a failed task reports its progress
    /// to the root task. A root task is the earliest task in a chain of tasks.
    /// During execution of `transform`, an additional progress object created
    /// using the current parent will also contribute to the chain's progress.
    ///
    /// The resulting task is cancellable in the same way the receiving task is.
    ///
    /// - see: FutureProtocol.map(upon:transform:)
    public func recover(upon executor: Executor, substituting substitution: @escaping(Failure) throws -> Success) -> Task<Success> {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        let chain = TaskChain(andThenFrom: self)
        #endif

        let future: Future = map(upon: executor) { (result) -> Task<Success>.Result in
            #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
            chain.beginMap()
            defer { chain.commitMap() }
            #endif

            return Task<Success>.Result {
                do {
                    return try result.get()
                } catch {
                    return try substitution(error)
                }
            }
        }

        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        return Task<Success>(future, progress: chain.effectiveProgress)
        #else
        return Task<Success>(future, uponCancel: cancel)
        #endif
    }
}
