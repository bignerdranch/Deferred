//
//  TaskUpon.swift
//  Deferred
//
//  Created by Zachary Waldowski on 12/26/15.
//  Copyright © 2015-2019 Big Nerd Ranch. Licensed under MIT.
//

#if SWIFT_PACKAGE
import Deferred
#endif

extension TaskProtocol {
    /// Call some `body` closure if the task successfully completes.
    ///
    /// - seealso: `TaskProtocol.uponSuccess(on:execute:)`
    /// - see: `FutureProtocol.upon(_:execute:)`
    public func uponSuccess(on executor: PreferredExecutor = Self.defaultUponExecutor, execute body: @escaping(_ value: Success) -> Void) {
        uponSuccess(on: executor as Executor, execute: body)
    }

    public func uponSuccess(on executor: Executor, execute body: @escaping(_ value: Success) -> Void) {
        upon(executor) { (result) in
            do {
                try body(result.get())
            } catch {}
        }
    }

    /// Call some `body` closure if the task fails.
    ///
    /// - seealso: `TaskProtocol.uponFailure(on:execute:)`
    /// - seealso: `FutureProtocol.upon(_:execute:)`
    public func uponFailure(on executor: PreferredExecutor = Self.defaultUponExecutor, execute body: @escaping(_ error: Failure) -> Void) {
        uponFailure(on: executor as Executor, execute: body)
    }

    public func uponFailure(on executor: Executor, execute body: @escaping(_ error: Failure) -> Void) {
        upon(executor) { result in
            do {
                _ = try result.get()
            } catch {
                body(error)
            }
        }
    }
}
