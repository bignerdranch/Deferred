//
//  Deferred.swift
//  Deferred
//
//  Created by John Gallagher on 7/19/14.
//  Copyright © 2014-2015 Big Nerd Ranch. Licensed under MIT.
//

// This cannot be a class var, new storage would be created for every
// specialization. It also could not be used as a default argument as it is now.
private var DeferredDefaultQueue: dispatch_queue_t {
    return dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
}

/// A deferred is a value that may become determined (or "filled") at some point
/// in the future. Once a deferred value is determined, it cannot change.
public struct Deferred<Value> {
    typealias UponBlock = (dispatch_queue_t, Value -> ())
    private typealias Protected = (protected: Value?, uponBlocks: [UponBlock])
    
    private var protected: LockProtected<Protected>
    
    private init(_ value: Value?) {
        protected = LockProtected(item: (value, []))
    }
    
    /// Initialize an unfilled Deferred.
    public init() {
        self.init(nil)
    }
    
    /// Initialize a filled Deferred with the given value.
    public init(value: Value) {
        self.init(value)
    }
    
    /// Check whether or not the receiver is filled.
    public var isFilled: Bool {
        return protected.withReadLock { $0.protected != nil }
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
        let (filledValue, blocks) = protected.withWriteLock { data -> (Value, [UponBlock]) in
            if assertIfFilled {
                precondition(data.protected == nil, "Cannot fill an already-filled Deferred", file: file, line: line)
                data.protected = value
            } else if data.protected == nil {
                data.protected = value
            }
            let blocks = data.uponBlocks
            data.uponBlocks.removeAll(keepCapacity: false)
            return (data.protected!, blocks)
        }
        for (queue, block) in blocks {
            dispatch_async(queue) { block(filledValue) }
        }
    }
    
    /**
    Checks for and returns a determined value.
    
    :returns: The determined value, if already filled, or `nil`.
    */
    public func peek() -> Value? {
        return protected.withReadLock { $0.protected }
    }
    
    /**
    Call some function once the value is determined.
    
    If the value is already determined, the function will be submitted to the
    queue immediately. An `upon` call is always executed asynchronously.
    
    :param: queue A dispatch queue for executing the given function on.
    :param: function A function that uses the determined value.
    */
    public func upon(queue: dispatch_queue_t = DeferredDefaultQueue, function: Value -> ()) {
        let maybeValue: Value? = protected.withWriteLock{ data in
            if data.protected == nil {
                data.uponBlocks.append( (queue, function) )
            }
            return data.protected
        }
        if let value = maybeValue {
            dispatch_async(queue) { function(value) }
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
}

extension Deferred {
    /**
    Waits for the value to become determined, then returns it.

    This is equivalent to unwrapping the value of calling `wait(.Forever)`, but
    may be more efficient.

    This getter will unnecessarily block execution. It might be useful for
    testing, but otherwise it should be strictly avoided.

    :returns: The determined value.
    */
    public var value: Value {
        // fast path - return if already filled
        if let v = peek() {
            return v
        }

        // slow path - block until filled
        let group = dispatch_group_create()
        var result: Value!
        dispatch_group_enter(group)
        self.upon { result = $0; dispatch_group_leave(group) }
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER)
        return result
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
    public func flatMap<NewValue>(upon queue: dispatch_queue_t = DeferredDefaultQueue, transform: Value -> Deferred<NewValue>) -> Deferred<NewValue> {
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
    public func map<NewValue>(upon queue: dispatch_queue_t = DeferredDefaultQueue, transform: Value -> NewValue) -> Deferred<NewValue> {
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

    dispatch_group_notify(group, DeferredDefaultQueue) {
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
