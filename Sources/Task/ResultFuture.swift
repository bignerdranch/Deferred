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

extension FutureType where Value: ResultType {
    private func commonSuccessBody(_ body: @escaping(Value.Value) -> Void) -> (Value) -> Void {
        return { result in
            result.withValues(ifSuccess: body, ifFailure: { _ in () })
        }
    }

    private func commonFailureBody(_ body: @escaping(Error) -> Void) -> (Value) -> Void {
        return { result in
            result.withValues(ifSuccess: { _ in () }, ifFailure: body)
        }
    }

    /// Call some `body` closure if the future successfully resolves a value.
    ///
    /// - parameter executor: A context for handling the `body` on fill.
    /// - parameter body: A closure that uses the determined success value.
    /// - seealso: upon(_:body:)
    public func uponSuccess(_ executor: ExecutorType, _ body: @escaping(Value.Value) -> Void) {
        upon(executor, body: commonSuccessBody(body))
    }

    /// Call some `body` closure if the future produces an error.
    ///
    /// - parameter executor: A context for handling the `body` on fill.
    /// - parameter body: A closure that uses the determined failure value.
    /// - seealso: upon(_:body:)
    public func uponFailure(_ executor: ExecutorType, _ body: @escaping(Error) -> Void) {
        upon(executor, body: commonFailureBody(body))
    }

    /// Call some `body` closure if the future successfully resolves a value.
    ///
    /// - seealso: `uponSuccess(_:body:)`.
    /// - seealso: `upon(_:body:)`.
    public func uponSuccess(_ queue: DispatchQueue, _ body: @escaping(Value.Value) -> Void) {
        upon(queue, body: commonSuccessBody(body))
    }

    /// Call some `body` closure if the future produces an error.
    ///
    /// - seealso: `uponFailure(_:body:)`.
    /// - seealso: `upon(_:body:)`.
    public func uponFailure(_ queue: DispatchQueue, _ body: @escaping(Error) -> Void) {
        upon(queue, body: commonFailureBody(body))
    }

    /// Call some `body` in the background if the future successfully resolves
    /// a value.
    ///
    /// - seealso: `uponSuccess(_:body:)`.
    public func uponSuccess(_ body: @escaping(Value.Value) -> Void) {
        upon(Self.genericQueue, body: commonSuccessBody(body))
    }

    /// Call some `body` in the background if the future produces an error.
    ///
    /// - seealso: `uponFailure(_:body:)`.
    public func uponFailure(_ body: @escaping(Error) -> Void) {
        upon(Self.genericQueue, body: commonFailureBody(body))
    }
}
