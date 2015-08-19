//
//  Deferred.swift
//  Deferred
//
//  Created by John Gallagher on 7/19/14.
//  Copyright © 2014-2015 Big Nerd Ranch. Licensed under MIT.
//

private final class Storage<T> {

    var value: T

    init(_ value: T) {
        self.value = value
    }

}

// Used for keying into the queue-specific storage
private var QueueSideTableKey = 0

// This cannot be a class var, new storage would be created for every
// specialization. It also could not be used as a default argument as it is now.
private var DeferredDefaultQueue: dispatch_queue_t {
    return dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)
}

public enum Timeout {
    case Now
    case Forever
    case Interval(NSTimeInterval)

    private var rawValue: dispatch_time_t {
        switch self {
        case .Now:
            return DISPATCH_TIME_NOW
        case .Forever:
            return DISPATCH_TIME_FOREVER
        case .Interval(let time):
            return dispatch_time(DISPATCH_TIME_NOW, Int64(time * Double(NSEC_PER_SEC)))
        }
    }
}

public struct Deferred<Value> {
    private let accessQueue: dispatch_queue_t
    private let onFilled: dispatch_block_t

    private static var currentStorage: Storage<Value?> {
        let boxPtr = dispatch_get_specific(&QueueSideTableKey)
        assert(boxPtr != nil, "Deferred side-table should not be accessed off-queue")
        let boxRef = Unmanaged<Storage<Value?>>.fromOpaque(COpaquePointer(boxPtr))
        return boxRef.takeUnretainedValue()
    }

    private init(_ value: Value?) {
        accessQueue = dispatch_queue_create("Deferred", DISPATCH_QUEUE_CONCURRENT)
        onFilled = dispatch_block_create(nil) {}
        deferred_queue_set_specific_object(accessQueue, &QueueSideTableKey, Storage(value))
        if value != nil {
            onFilled()
        }
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
        return dispatch_block_wait(onFilled, DISPATCH_TIME_NOW) == 0
    }

    public func fill(value: Value, assertIfFilled: Bool = true, file: StaticString = __FILE__, line: UWord = __LINE__) {
        dispatch_barrier_async(accessQueue) { [filled = onFilled] in
            let box = Deferred.currentStorage
            switch (box.value, assertIfFilled) {
            case (.None, _):
                box.value = value
                filled()
            case (.Some, false):
                break
            case (.Some, _):
                preconditionFailure("Cannot fill an already-filled Deferred", file: file, line: line)
            }
        }
    }

    public func fillIfUnfilled(value: Value) {
        fill(value, assertIfFilled: false)
    }

    public func upon(_ queue: dispatch_queue_t = DeferredDefaultQueue, function: Value -> ()) {
        dispatch_async(accessQueue) { [block = onFilled] in
            dispatch_block_notify(block, queue) { [box = Deferred.currentStorage] in
                box.value.map(function)
            }
        }
    }

    public func wait(time: Timeout) -> Value? {
        var value: Value?
        let block = dispatch_block_create(nil) {
            value = Deferred.currentStorage.value
        }

        dispatch_block_notify(onFilled, accessQueue, block)
        if dispatch_block_wait(block, time.rawValue) != 0 {
            dispatch_block_cancel(block)
        }

        return value
    }
}

extension Deferred {
    public func peek() -> Value? {
        return wait(.Now)
    }

    public var value: Value {
        return unsafeUnwrap(wait(.Forever))
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
