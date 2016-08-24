//
//  Deferred.swift
//  Deferred
//
//  Created by John Gallagher on 7/19/14.
//  Copyright © 2014-2015 Big Nerd Ranch. Licensed under MIT.
//

import Dispatch

// MARK: - DispatchBlockMarker

// A dispatch block (which is different from a plain closure!) constitutes the
// second half of Deferred. The `dispatch_block_notify` API defines the notifier
// list used by `Deferred.upon(queue:body:)`.
private struct DispatchBlockMarker: CallbacksList {
    let block = dispatch_block_create(DISPATCH_BLOCK_NO_QOS_CLASS, {
        fatalError("This code should never be executed")
    })
    
    var isCompleted: Bool {
        return dispatch_block_testcancel(block) != 0
    }
    
    func markCompleted() {
        // Cancel it so we can use `dispatch_block_testcancel` to mean "filled"
        dispatch_block_cancel(block)
        // Executing the block "unblocks" it, calling all the `_notify` blocks
        block()
    }

    func notify(executor executor: ExecutorType, body: dispatch_block_t) {
        if let queue = executor.underlyingQueue {
            dispatch_block_notify(block, queue, body)
        } else {
            dispatch_block_notify(block, Deferred<Void>.genericQueue) {
                executor.submit(body)
            }
        }
    }
}

// MARK: - Deferred

/// A deferred is a value that may become determined (or "filled") at some point
/// in the future. Once a deferred value is determined, it cannot change.
public struct Deferred<Value>: FutureType, PromiseType {

    private let storage: MemoStore<Value>
    private let onFilled = DispatchBlockMarker()
    
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

    private func upon(executor: ExecutorType, per options: dispatch_block_flags_t, execute body: Value -> Void) -> dispatch_block_t {
        var options = options
        options.rawValue |= DISPATCH_BLOCK_ASSIGN_CURRENT.rawValue
        let block = dispatch_block_create(options) { [storage] in
            storage.withValue(body)
        }
        onFilled.notify(executor: executor, body: block)
        return block
    }

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
    public func upon(executor: ExecutorType, body: Value -> Void) {
        _ = upon(executor, per: DISPATCH_BLOCK_INHERIT_QOS_CLASS, execute: body)
    }

    /// Waits synchronously for the value to become determined.
    ///
    /// If the value is already determined, the call returns immediately with
    /// the value.
    ///
    /// - parameter time: A length of time to wait for the value to be determined.
    /// - returns: The determined value, if filled within the timeout, or `nil`.
    public func wait(time: Timeout) -> Value? {
        var result: Value?
        func assign(value: Value) {
            result = value
        }

        // FutureType can't generally do this; `isFilled` is normally
        // implemented in terms of wait() normally.
        if isFilled {
            storage.withValue(assign)
            return result
        }

        let executor = QueueExecutor(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0))
        let handler = upon(executor, per: DISPATCH_BLOCK_ENFORCE_QOS_CLASS, execute: assign)

        guard dispatch_block_wait(handler, time.rawValue) == 0 else {
            dispatch_block_cancel(handler)
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
    public func fill(value: Value) -> Bool {
        let wasFilled = storage.fill(value)
        if wasFilled {
            onFilled.markCompleted()
        }
        return wasFilled
    }
}
