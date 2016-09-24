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
    let block = DispatchWorkItem {
        fatalError("This code should never be executed")
    }
    
    var isCompleted: Bool {
        return block.isCancelled
    }
    
    func markCompleted() {
        // Cancel it so we can use `dispatch_block_testcancel` to mean "filled"
        block.cancel()
        // Executing the block "unblocks" it, calling all the `_notify` blocks
        block.perform()
    }

    func notify(upon executor: ExecutorType, body: DispatchWorkItem) {
        if let queue = executor.underlyingQueue {
            block.notify(queue: queue, execute: body)
        } else {
            block.notify(queue: Deferred<Void>.genericQueue) {
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
        storage = MemoStore.create(with: nil)
    }
    
    /// Initialize a Deferred filled with the given value.
    public init(value: Value) {
        storage = MemoStore.create(with: value)
        onFilled.markCompleted()
    }

    // MARK: FutureType

    private func upon(_ executor: ExecutorType, per flags: DispatchWorkItemFlags, execute body: @escaping(Value) -> Void) -> DispatchWorkItem {
        let workItem = DispatchWorkItem(flags: flags.union(.assignCurrentContext)) { [storage] in
            storage.withValue(body)
        }
        onFilled.notify(upon: executor, body: workItem)
        return workItem
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
    public func upon(_ executor: ExecutorType, body: @escaping(Value) -> Void) {
        _ = upon(executor, per: .inheritQoS, execute: body)
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

        let executor = QueueExecutor(.global(qos: .utility))
        let handler = upon(executor, per: .enforceQoS, execute: assign)

        guard case .success = handler.wait(timeout: time.rawValue) else {
            handler.cancel()
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
    public func fill(_ value: Value) -> Bool {
        let wasFilled = storage.fill(value)
        if wasFilled {
            onFilled.markCompleted()
        }
        return wasFilled
    }
}
