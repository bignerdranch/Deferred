//
//  Deferred.swift
//  Deferred
//
//  Created by John Gallagher on 7/19/14.
//  Copyright © 2014-2015 Big Nerd Ranch. Licensed under MIT.
//

import Dispatch

// MARK: - DispatchCompletionMarker

// A Dispatch work item constitutes the second half of Deferred. The `notify`
// family of API defines the notifier list used by `Deferred.upon(_:body:)`.
private extension DispatchWorkItem {

    convenience init() {
        self.init { fatalError("This code should never be executed") }
    }

    var isCompleted: Bool {
        return isCancelled
    }

    func markCompleted() {
        // Cancel it so we can use `dispatch_block_testcancel` to mean "filled"
        cancel()
        // Executing the block "unblocks" it, calling all the `_notify` blocks
        perform()
    }

}

// MARK: - Deferred

/// A deferred is a value that may become determined (or "filled") at some point
/// in the future. Once a deferred value is determined, it cannot change.
public struct Deferred<Value>: FutureType, PromiseType {

    private let storage: MemoStore<Value>
    private let onFilled = DispatchWorkItem()
    
    /// Initialize an unfilled Deferred.
    public init() {
        storage = MemoStore.createWithValue(nil)
    }
    
    /// Initialize a Deferred filled with the given value.
    public init(value: Value) {
        storage = MemoStore.createWithValue(value)
        onFilled.markCompleted()
    }

    // MARK: FutureType

    /// Check whether or not the receiver is filled.
    public var isFilled: Bool {
        return onFilled.isCompleted
    }

    /// Call some `body` closure once the value is determined.
    ///
    /// If the value is determined, the function will be submitted to
    /// to the `executor` immediately.
    ///
    /// - parameter executor: A context for handling the `body` on fill.
    /// - parameter body: A function that uses the determined value.
    public func upon(_ executor: ExecutorType, body: @escaping(Value) -> Void) {
        func callBodyWithValue() {
            storage.withValue(body)
        }

        if let queue = executor.underlyingQueue {
            onFilled.notify(flags: [.assignCurrentContext, .inheritQoS], queue: queue, execute: callBodyWithValue)
        } else {
            let queue = type(of: self).genericQueue
            onFilled.notify(flags: .assignCurrentContext, queue: queue) {
                executor.submit(callBodyWithValue)
            }
        }
    }

    /// Waits synchronously for the value to become determined.
    ///
    /// If the value is already determined, the call returns immediately with
    /// the value.
    ///
    /// - parameter time: A length of time to wait for the value to be determined.
    /// - returns: The determined value, if filled within the timeout, or `nil`.
    public func wait(_ time: Timeout) -> Value? {
        var result: Value?
        func assign(_ value: Value) {
            result = value
        }

        // FutureType can't generally do this; `isFilled` is normally
        // implemented in terms of wait() normally.
        if isFilled {
            storage.withValue(assign)
            return result
        }

        let callback = DispatchWorkItem(flags: [.assignCurrentContext, .enforceQoS]) { [storage] in
            storage.withValue(assign)
        }

        onFilled.notify(queue: .global(), execute: callback)

        guard case .success = callback.wait(timeout: .init(time)) else {
            callback.cancel()
            return nil
        }

        return result
    }

    // MARK: PromiseType
    
    /// Determines the deferred value with a given result.
    ///
    /// Filling a deferred value should usually be attempted only once.
    ///
    /// - parameter value: The resolved value for the instance.
    /// - returns: Whether the promise was fulfilled with `value`.
    @discardableResult
    public func fill(_ value: Value) -> Bool {
        let wasFilled = storage.fill(value)
        if wasFilled {
            onFilled.markCompleted()
        }
        return wasFilled
    }
}
