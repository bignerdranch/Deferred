//
//  ResultFuture.swift
//  Deferred
//
//  Created by Zachary Waldowski on 12/26/15.
//  Copyright © 2015-2016 Big Nerd Ranch. Licensed under MIT.
//

#if SWIFT_PACKAGE
import Deferred
import Result
#endif
import Dispatch

private extension FutureProtocol where Value: Either {
    func commonSuccessBody(_ body: @escaping(Value.Right) -> Void) -> (Value) -> Void {
        return { result in
            result.withValues(ifLeft: { _ in () }, ifRight: body)
        }
    }

    func commonFailureBody(_ body: @escaping(Value.Left) -> Void) -> (Value) -> Void {
        return { result in
            result.withValues(ifLeft: body, ifRight: { _ in () })
        }
    }
}

extension FutureProtocol where Value: Either {
    /// Call some `body` closure if the future successfully resolves a value.
    ///
    /// - parameter executor: A context for handling the `body` on fill.
    /// - parameter body: A closure that uses the determined success value.
    /// - seealso: upon(_:body:)
    public func uponSuccess(_ executor: Executor, execute body: @escaping(Value.Right) -> Void) {
        upon(executor, execute: commonSuccessBody(body))
    }

    /// Call some `body` closure if the future produces an error.
    ///
    /// - parameter executor: A context for handling the `body` on fill.
    /// - parameter body: A closure that uses the determined failure value.
    /// - seealso: upon(_:body:)
    public func uponFailure(_ executor: Executor, execute body: @escaping(Value.Left) -> Void) {
        upon(executor, execute: commonFailureBody(body))
    }

    /// Call some `body` closure if the future successfully resolves a value.
    ///
    /// - seealso: `uponSuccess(_:body:)`.
    /// - seealso: `upon(_:body:)`.
    public func uponSuccess(_ executor: PreferredExecutor, execute body: @escaping(Value.Right) -> Void) {
        upon(executor, execute: commonSuccessBody(body))
    }

    /// Call some `body` closure if the future produces an error.
    ///
    /// - seealso: `uponFailure(_:body:)`.
    /// - seealso: `upon(_:body:)`.
    public func uponFailure(_ executor: PreferredExecutor, execute body: @escaping(Value.Left) -> Void) {
        upon(executor, execute: commonFailureBody(body))
    }
}

extension FutureProtocol where Value: Either, PreferredExecutor == DispatchQueue {
    /// Call some `body` in the background if the future successfully resolves
    /// a value.
    ///
    /// - seealso: `uponSuccess(_:body:)`.
    public func uponSuccess(execute body: @escaping(Value.Right) -> Void) {
        upon(.any(), execute: commonSuccessBody(body))
    }

    /// Call some `body` in the background if the future produces an error.
    ///
    /// - seealso: `uponFailure(_:body:)`.
    public func uponFailure(execute body: @escaping(Value.Left) -> Void) {
        upon(.any(), execute: commonFailureBody(body))
    }
}
