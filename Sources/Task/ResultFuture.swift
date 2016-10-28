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
    /// - see: upon(_:execute:)
    public func uponSuccess(on executor: Executor, execute body: @escaping(Value.Right) -> Void) {
        upon(executor, execute: commonSuccessBody(body))
    }

    /// Call some `body` closure if the future produces an error.
    ///
    /// - parameter executor: A context for handling the `body` on fill.
    /// - parameter body: A closure that uses the determined failure value.
    /// - see: upon(_:execute:)
    public func uponFailure(on executor: Executor, execute body: @escaping(Value.Left) -> Void) {
        upon(executor, execute: commonFailureBody(body))
    }

    /// Call some `body` closure if the future successfully resolves a value.
    ///
    /// - see: uponSuccess(on:execute:)
    /// - see: upon(_:execute:)
    public func uponSuccess(on executor: PreferredExecutor, execute body: @escaping(Value.Right) -> Void) {
        upon(executor, execute: commonSuccessBody(body))
    }

    /// Call some `body` closure if the future produces an error.
    ///
    /// - see: uponFailure(on:execute:)
    /// - see: upon(_:body:)
    public func uponFailure(on executor: PreferredExecutor, execute body: @escaping(Value.Left) -> Void) {
        upon(executor, execute: commonFailureBody(body))
    }
}

extension FutureProtocol where Value: Either, PreferredExecutor == DispatchQueue {
    /// Call some `body` in the background if the future successfully resolves
    /// a value.
    ///
    /// - see: uponSuccess(on:execute:)
    public func uponSuccess(execute body: @escaping(Value.Right) -> Void) {
        upon(.any(), execute: commonSuccessBody(body))
    }

    /// Call some `body` in the background if the future produces an error.
    ///
    /// - see: uponFailure(on:execute:)
    public func uponFailure(execute body: @escaping(Value.Left) -> Void) {
        upon(.any(), execute: commonFailureBody(body))
    }
}

extension Future where Value: Either {
    /// Create a future having the same underlying task as `other`.
    public init<Other: FutureProtocol>(task other: Other)
        where Other.Value: Either, Other.Value.Left == Error, Other.Value.Right == Value.Right {
        self.init(other.every {
            Value(from: $0.extract)
        })
    }
}
