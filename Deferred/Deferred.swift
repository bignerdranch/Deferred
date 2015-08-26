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

public struct Deferred<Value> {
    typealias UponBlock = (dispatch_queue_t, Value -> ())
    private typealias Protected = (protected: Value?, uponBlocks: [UponBlock])

    private var protected: LockProtected<Protected>

    private init(_ value: Value?) {
        protected = LockProtected(item: (value, []))
    }

    // Initialize an unfilled Deferred
    public init() {
        self.init(nil)
    }

    // Initialize a filled Deferred with the given value
    public init(value: Value) {
        self.init(value)
    }

    // Check whether or not the receiver is filled
    public var isFilled: Bool {
        return protected.withReadLock { $0.protected != nil }
    }
    
    public func fill(value: Value, assertIfFilled: Bool = true) {
        let (filledValue, blocks) = protected.withWriteLock { data -> (Value, [UponBlock]) in
            if assertIfFilled {
                precondition(data.protected == nil, "Cannot fill an already-filled Deferred")
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

    public func fillIfUnfilled(value: Value) {
        fill(value, assertIfFilled: false)
    }

    public func peek() -> Value? {
        return protected.withReadLock { $0.protected }
    }

    public func upon(_ queue: dispatch_queue_t = DeferredDefaultQueue, function: Value -> ()) {
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
}

extension Deferred {
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
    public func flatMap<NewValue>(upon queue: dispatch_queue_t = DeferredDefaultQueue, transform: Value -> Deferred<NewValue>) -> Deferred<NewValue> {
        let d = Deferred<NewValue>()
        upon(queue) {
            transform($0).upon(queue) {
                d.fill($0)
            }
        }
        return d
    }

    public func map<NewValue>(upon queue: dispatch_queue_t = DeferredDefaultQueue, transform: Value -> NewValue) -> Deferred<NewValue> {
        let d = Deferred<NewValue>()
        upon(queue) {
            d.fill(transform($0))
        }
        return d
    }
}

extension Deferred {
    public func both<OtherValue>(other: Deferred<OtherValue>) -> Deferred<(Value, OtherValue)> {
        return flatMap { t in other.map { u in (t, u) } }
    }
}

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

public func any<Value, Sequence: SequenceType where Sequence.Generator.Element == Deferred<Value>>(deferreds: Sequence) -> Deferred<Deferred<Value>> {
    let combined = Deferred<Deferred<Value>>()
    for d in deferreds {
        d.upon { _ in combined.fillIfUnfilled(d) }
    }
    return combined
}
