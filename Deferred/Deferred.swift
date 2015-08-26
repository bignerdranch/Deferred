//
//  Deferred.swift
//  Deferred
//
//  Created by John Gallagher on 7/19/14.
//  Copyright © 2014-2015 Big Nerd Ranch. Licensed under MIT.
//

import Foundation

// TODO: Replace this with a class var
private var DeferredDefaultQueue: dispatch_queue_t {
    return dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
}

public final class Deferred<T> {
    typealias UponBlock = (dispatch_queue_t, T -> ())
    private typealias Protected = (protectedValue: T?, uponBlocks: [UponBlock])

    private var protected: LockProtected<Protected>
    private let defaultQueue: dispatch_queue_t

    private init(value: T?, queue: dispatch_queue_t) {
        protected = LockProtected(item: (value, []))
        self.defaultQueue = queue
    }

    // Initialize an unfilled Deferred
    public convenience init(defaultQueue: dispatch_queue_t = DeferredDefaultQueue) {
        self.init(value: nil, queue: defaultQueue)
    }

    // Initialize a filled Deferred with the given value
    public convenience init(value: T, defaultQueue: dispatch_queue_t = DeferredDefaultQueue) {
        self.init(value: value, queue: defaultQueue)
    }

    // Check whether or not the receiver is filled
    public var isFilled: Bool {
        return protected.withReadLock { $0.protectedValue != nil }
    }

    private func _fill(value: T, assertIfFilled: Bool) {
        let (filledValue, blocks) = protected.withWriteLock { data -> (T, [UponBlock]) in
            if assertIfFilled {
                precondition(data.protectedValue == nil, "Cannot fill an already-filled Deferred")
                data.protectedValue = value
            } else if data.protectedValue == nil {
                data.protectedValue = value
            }
            let blocks = data.uponBlocks
            data.uponBlocks.removeAll(keepCapacity: false)
            return (data.protectedValue!, blocks)
        }
        for (queue, block) in blocks {
            dispatch_async(queue) { block(filledValue) }
        }
    }

    public func fill(value: T) {
        _fill(value, assertIfFilled: true)
    }

    public func fillIfUnfilled(value: T) {
        _fill(value, assertIfFilled: false)
    }

    public func peek() -> T? {
        return protected.withReadLock { $0.protectedValue }
    }

    public func upon(_ inQueue: dispatch_queue_t? = nil, function: T -> ()) {
        let queue = inQueue ?? defaultQueue
        let maybeValue: T? = protected.withWriteLock{ data in
            if data.protectedValue == nil {
                data.uponBlocks.append( (queue, function) )
            }
            return data.protectedValue
        }
        if let value = maybeValue {
            dispatch_async(queue) { function(value) }
        }
    }
}

extension Deferred {
    public var value: T {
        // fast path - return if already filled
        if let v = peek() {
            return v
        }

        // slow path - block until filled
        let group = dispatch_group_create()
        var result: T!
        dispatch_group_enter(group)
        self.upon { result = $0; dispatch_group_leave(group) }
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER)
        return result
    }
}

extension Deferred {
    public func flatMap<U>(upon queue: dispatch_queue_t = DeferredDefaultQueue, transform: T -> Deferred<U>) -> Deferred<U> {
        let d = Deferred<U>()
        upon(queue) {
            transform($0).upon(queue) {
                d.fill($0)
            }
        }
        return d
    }

    public func map<U>(upon queue: dispatch_queue_t = DeferredDefaultQueue, transform: T -> U) -> Deferred<U> {
        return flatMap(upon: queue) { t in Deferred<U>(value: transform(t)) }
    }
}

extension Deferred {
    public func both<U>(other: Deferred<U>) -> Deferred<(T,U)> {
        return self.flatMap { t in other.map { u in (t, u) } }
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
        deferred.upon(DeferredDefaultQueue) { _ in
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
