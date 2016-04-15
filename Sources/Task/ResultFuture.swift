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

private func commonUponSuccess<Result: ResultType>(body: Result.Value -> Void) -> (Result) -> Void {
    return { result in
        result.withValues(ifSuccess: body, ifFailure: { _ in () })
    }
}

private func commonUponFailure<Result: ResultType>(body: ErrorType -> Void) -> (Result) -> Void {
    return { result in
        result.withValues(ifSuccess: { _ in () }, ifFailure: body)
    }
}

extension FutureType where Value: ResultType {
    /// Call some `body` closure if the future successfully resolves a value.
    ///
    /// - parameter executor: A context for handling the `body` on fill.
    /// - parameter body: A closure that uses the determined success value.
    /// - seealso: upon(_:body:)
    public func uponSuccess(executor: ExecutorType, body: Value.Value -> Void) {
        upon(executor, body: commonUponSuccess(body))
    }

    /// Call some `body` closure if the future produces an error.
    ///
    /// - parameter executor: A context for handling the `body` on fill.
    /// - parameter body: A closure that uses the determined failure value.
    /// - seealso: upon(_:body:)
    public func uponFailure(executor: ExecutorType, body: ErrorType -> Void) {
        upon(executor, body: commonUponFailure(body))
    }

    /// Call some `body` closure if the future successfully resolves a value.
    ///
    /// - seealso: `uponSuccess(_:body:)`.
    /// - seealso: `upon(_:body:)`.
    public func uponSuccess(queue: dispatch_queue_t, body: Value.Value -> Void) {
        upon(queue, body: commonUponSuccess(body))
    }

    /// Call some `body` closure if the future produces an error.
    ///
    /// - seealso: `uponFailure(_:body:)`.
    /// - seealso: `upon(_:body:)`.
    public func uponFailure(queue: dispatch_queue_t, body: ErrorType -> Void) {
        upon(queue, body: commonUponFailure(body))
    }

    /// Call some `body` in the background if the future successfully resolves
    /// a value.
    ///
    /// - seealso: `uponSuccess(_:body:)`.
    public func uponSuccess(body: Value.Value -> Void) {
        upon(Self.genericQueue, body: commonUponSuccess(body))
    }

    /// Call some `body` in the background if the future produces an error.
    ///
    /// - seealso: `uponFailure(_:body:)`.
    public func uponFailure(body: ErrorType -> Void) {
        upon(Self.genericQueue, body: commonUponFailure(body))
    }
}

extension Future where Value: ResultType {
    /// Create a future having the same underlying task as `other`.
    public init<Other: FutureType where Other.Value: ResultType, Other.Value.Value == Value.Value>(_ other: Other) {
        self = other.map {
            Value(with: $0.extract)
        }
    }
}
