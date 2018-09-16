//
//  TaskUpon.swift
//  Deferred
//
//  Created by Zachary Waldowski on 12/26/15.
//  Copyright © 2015-2018 Big Nerd Ranch. Licensed under MIT.
//

#if SWIFT_PACKAGE
import Deferred
#endif

extension TaskProtocol {
    /// Call some `body` closure if the task successfully completes.
    ///
    /// - seealso: `TaskProtocol.uponSuccess(on:execute:)`
    /// - see: `FutureProtocol.upon(_:execute:)`
    public func uponSuccess(on executor: PreferredExecutor = Self.defaultUponExecutor, execute body: @escaping(_ value: SuccessValue) -> Void) {
        uponSuccess(on: executor as Executor, execute: body)
    }

    public func uponSuccess(on executor: Executor, execute body: @escaping(_ value: SuccessValue) -> Void) {
        upon(executor) { (result) in
            result.withValues(ifLeft: { _ in () }, ifRight: body)
        }
    }

    /// Call some `body` closure if the task fails.
    ///
    /// - seealso: `TaskProtocol.uponFailure(on:execute:)`
    /// - seealso: `FutureProtocol.upon(_:execute:)`
    public func uponFailure(on executor: PreferredExecutor = Self.defaultUponExecutor, execute body: @escaping(_ error: FailureValue) -> Void) {
        uponFailure(on: executor as Executor, execute: body)
    }

    public func uponFailure(on executor: Executor, execute body: @escaping(_ error: FailureValue) -> Void) {
        upon(executor) { result in
            result.withValues(ifLeft: body, ifRight: { _ in () })
        }
    }
}
