//
//  Deferred.swift
//  Deferred
//
//  Created by John Gallagher on 7/19/14.
//  Copyright © 2014-2015 Big Nerd Ranch. Licensed under MIT.
//

import Dispatch

private final class Storage<T> {

    let value: T

    init(_ value: T) {
        self.value = value
    }

}

private var DeferredStorageKey = 0

private let ObjectDestructor: dispatch_function_t = { contextPtr in
    let storageRef = Unmanaged<AnyObject>.fromOpaque(COpaquePointer(contextPtr))
    storageRef.release()
}

private var genericQueue: dispatch_queue_t! {
    return dispatch_get_global_queue(qos_class_self(), 0)
}

/// A deferred is a value that may become determined (or "filled") at some point
/// in the future. Once a deferred value is determined, it cannot change.
public struct Deferred<Value> {
    private let accessQueue: dispatch_queue_t = {
        let attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_CONCURRENT, QOS_CLASS_UTILITY, 0)
        return dispatch_queue_create("Deferred", attr)
    }()
    private let onFilled = dispatch_block_create(DISPATCH_BLOCK_NO_QOS_CLASS, {})!

    private var isFilledLocked: Bool {
        return dispatch_get_specific(&DeferredStorageKey) != nil
    }

    private func fillLocked(value: Value) {
        let storage = Storage(value)
        let storagePtr = Unmanaged.passRetained(storage).toOpaque()
        dispatch_queue_set_specific(accessQueue, &DeferredStorageKey, UnsafeMutablePointer(storagePtr), ObjectDestructor)
        dispatch_block_cancel(onFilled)
        onFilled()
    }

    private func upon(options inFlags: dispatch_block_flags_t, function: Value -> Void) -> dispatch_block_t {
        let flags = dispatch_block_flags_t(inFlags.rawValue | DISPATCH_BLOCK_ASSIGN_CURRENT.rawValue)
        let block = dispatch_block_create(flags) {
            let storagePtr = dispatch_get_specific(&DeferredStorageKey)
            guard storagePtr != nil else { return }

            let storageRef = Unmanaged<Storage<Value>>.fromOpaque(COpaquePointer(storagePtr))
            let storage = storageRef.takeUnretainedValue()

            let value = storage.value
            function(value)
        }
        dispatch_block_notify(onFilled, accessQueue, block)
        return block
    }

    // MARK: -

    /// Check whether or not the receiver is filled.
    public var isFilled: Bool {
        return dispatch_block_testcancel(onFilled) != 0
    }

    /// Determines the deferred value with a given result.
    ///
    /// Filling a deferred value should usually be attempted only once, and by
    /// default filling will trap upon improper usage.
    ///
    /// * In playgrounds and unoptimized builds (the default for a "Debug"
    ///   configuration), program execution will be stopped at the caller in
    ///   a debuggable state.
    /// * In -O builds (the default for a "Release" configuration), program
    ///   execution will stop.
    /// * In -Ounchecked builds, the programming error is assumed to not exist.
    ///
    /// If your deferred requires multiple potential fillers to race, you may
    /// disable the precondition.
    ///
    /// :param: value The resolved value of the deferred.
    /// :param: assertIfFilled If `false`, race checking is disabled.
    public func fill(value: Value, assertIfFilled: Bool = true, file: StaticString = __FILE__, line: UInt = __LINE__) {
        dispatch_barrier_async(accessQueue) {
            switch (self.isFilledLocked, assertIfFilled) {
            case (false, _):
                self.fillLocked(value)
            case (true, false):
                break
            case (true, true):
                preconditionFailure("Cannot fill an already-filled Deferred", file: file, line: line)
            }
        }
    }
    
    /**
    Call some function once the value is determined.
    
    If the value is already determined, the function will be submitted to the
    queue immediately. An `upon` call is always executed asynchronously.
    
    :param: queue A dispatch queue for executing the given function on.
    :param: function A function that uses the determined value.
    */
    public func upon(queue: dispatch_queue_t = genericQueue, function: Value -> ()) {
        _ = upon(options: DISPATCH_BLOCK_INHERIT_QOS_CLASS) { value in
            dispatch_async(queue) {
                function(value)
            }
        }
    }
    


    /**
    Call some function on the main queue once the value is determined.
    
    If the value is already determined, the function will be submitted to the
    main queue immediately. The function is always executed asynchronously, even
    if the Deferred is filled from the main queue.
    
    :param: function A function that uses the determined value.
    */
    public func uponMainQueue(function: Value -> ()) {
        upon(dispatch_get_main_queue(), function: function)
    }

    /**
    Waits synchronously for the value to become determined.

    If the value is already determined, the call returns immediately with the
    value.

    :param: time A length of time to wait for the value to be determined.
    :returns: The determined value, if filled within the timeout, or `nil`.
    */
    public func wait(time: Timeout) -> Value? {
        var value: Value?
        let handler = upon(options: DISPATCH_BLOCK_ENFORCE_QOS_CLASS) {
            value = $0
        }

        guard dispatch_block_wait(handler, time.rawValue) == 0 else {
            dispatch_block_cancel(handler)
            return nil
        }

        return value
    }
}

extension Deferred {
    /// Initialize a filled Deferred with the given value.
    public init(value: Value) {
        self.init()
        fillLocked(value)
    }
}

extension Deferred {
    /**
    Checks for and returns a determined value.

    :returns: The determined value, if already filled, or `nil`.
    */
    public func peek() -> Value? {
        return wait(.Now)
    }

    /**
    Waits for the value to become determined, then returns it.

    This is equivalent to unwrapping the value of calling `wait(.Forever)`, but
    may be more efficient.

    This getter will unnecessarily block execution. It might be useful for
    testing, but otherwise it should be strictly avoided.

    :returns: The determined value.
    */
    internal var value: Value {
        return unsafeUnwrap(wait(.Forever))
    }
}

extension Deferred {
    /**
    Begins another asynchronous operation with the deferred value once it
    becomes determined.

    `flatMap` is similar to `map`, but `transform` returns another `Deferred`
    instead of an immediate value. Use `flatMap` when you want this deferred
    value to feed into another asynchronous fetch. You might hear this referred
    to as "chaining" or "binding".

    :param: queue A dispatch queue for starting the new operation on.
    :param: transform A function to start a new deferred given the receiving
    value.

    :returns: The new deferred value returned by the `transform`.
    **/
    public func flatMap<NewValue>(upon queue: dispatch_queue_t = genericQueue, transform: Value -> Deferred<NewValue>) -> Deferred<NewValue> {
        let d = Deferred<NewValue>()
        upon(queue) {
            transform($0).upon(queue) {
                d.fill($0)
            }
        }
        return d
    }

    /**
    Transforms the deferred value once it becomes determined.

    `map` executes a transform immediately when the deferred value is
    determined.

    :param: queue A dispatch queue for executing the transform on.
    :param: transform A function to create something using the deferred value.
    :returns: A new deferred value that is determined once the receiving
    deferred is determined.
    **/
    public func map<NewValue>(upon queue: dispatch_queue_t = genericQueue, transform: Value -> NewValue) -> Deferred<NewValue> {
        let d = Deferred<NewValue>()
        upon(queue) {
            d.fill(transform($0))
        }
        return d
    }
}

extension Deferred {
    /**
    Composes the receiving value with another.

    :param: other Any other deferred value.

    :returns: A value that becomes determined after both the reciever and the
    given values become determined.
    */
    public func both<OtherValue>(other: Deferred<OtherValue>) -> Deferred<(Value, OtherValue)> {
        return flatMap { t in other.map { u in (t, u) } }
    }
}

/**
Compose a number of deferred values into a single deferred array.

:param: deferreds Any collection whose elements are themselves deferred values.
:return: A deferred array that is determined once all the given values are
determined, in the same order.
**/
public func all<Value, Collection: CollectionType where Collection.Generator.Element == Deferred<Value>>(deferreds: Collection) -> Deferred<[Value]> {
    let array = Array(deferreds)
    if array.isEmpty {
        return Deferred(value: [])
    }

    let combined = Deferred<[Value]>()
    let group = dispatch_group_create()

    for deferred in array {
        dispatch_group_enter(group)
        deferred.upon { _ in
            dispatch_group_leave(group)
        }
    }

    dispatch_group_notify(group, genericQueue) {
        let results = array.map { $0.value }
        combined.fill(results)
    }

    return combined
}

/**
Choose the deferred value that is determined first.

:param: deferreds Any collection whose elements are themselves deferred values.
:return: A deferred value that is determined with the first of the given
deferred values to be determined.
**/
public func any<Value, Sequence: SequenceType where Sequence.Generator.Element == Deferred<Value>>(deferreds: Sequence) -> Deferred<Value> {
    let combined = Deferred<Value>()
    for d in deferreds {
        d.upon { t in combined.fill(t, assertIfFilled: false) }
    }
    return combined
}
