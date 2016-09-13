//
//  Deferred.swift
//  Deferred
//
//  Created by John Gallagher on 7/19/14.
//  Copyright © 2014-2015 Big Nerd Ranch. Licensed under MIT.
//

import Dispatch
import Atomics

// MARK: - DispatchBlockMarker

// A dispatch block (which is different from a plain closure!) constitutes the
// second half of Deferred. The `dispatch_block_notify` API defines the notifier
// list used by `Deferred.upon(queue:body:)`.
private struct DispatchBlockMarker {
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

    private let storage: DeferredStorage<Value>
    private let onFilled = DispatchBlockMarker()

    /// Initialize an unfilled Deferred.
    public init() {
        storage = DeferredStorage.create(with: nil)
    }
    
    /// Initialize a Deferred filled with the given value.
    public init(value: Value) {
        storage = DeferredStorage.create(with: value)
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
    @discardableResult
    public func fill(_ value: Value) -> Bool {
        let wasFilled = storage.fill(value)
        if wasFilled {
            onFilled.markCompleted()
        }
        return wasFilled
    }
}

// Heap storage that is initialized with a value once-and-only-once, atomically.
final private class DeferredStorage<Value> {

    // Using `ManagedBufferPointer` has advantages over a custom class:
    //  - The buffer has a stable pointer when locked to a single element.
    //  - Better `holdsUniqueReference` support allows for future optimization.
    private typealias BufferPointer =
        ManagedBufferPointer<Void, AnyObject?>
    private typealias Storage = DeferredStorage<Value>

    static func create(with value: Value?) -> DeferredStorage<Value> {
        let pointer = BufferPointer(bufferClass: self, minimumCapacity: 1) { _ in }
        pointer.withUnsafeMutablePointerToElements { (boxPtr) in
            boxPtr.initialize(to: value.map { $0 as AnyObject })
        }
        return unsafeDowncast(pointer.buffer, to: self)
    }

    deinit {
        buffer.withUnsafeMutablePointers { (pointerToHeader, pointerToElements) -> Void in
            pointerToElements.deinitialize()
            pointerToHeader.deinitialize()
        }
    }

    private var buffer: BufferPointer {
        return BufferPointer(unsafeBufferObject: self)
    }

    func withValue(_ body: (Value) -> Void) {
        buffer.withUnsafeMutablePointerToElements { target in
            guard let ptr = target.withMemoryRebound(to: UnsafeAtomicRawPointer.self, capacity: 1, {
                $0.pointee.load(order: .relaxed)
            }), let unboxed = Unmanaged<AnyObject>.fromOpaque(ptr).takeUnretainedValue() as? Value else { return }

            body(unboxed)
        }
    }

    // Atomic compare-and-swap, but safe for an initialize-once, owning pointer:
    //  - ObjC: "MyObject *__strong *"
    //  - Swift: "UnsafeMutablePointer<MyObject!>"
    // If the assignment is made, the new value is retained by its owning pointer.
    // If the assignment is not made, the new value is not retained.
    func fill(_ value: Value) -> Bool {
        let newPtr = Unmanaged.passRetained(value as AnyObject).toOpaque()

        let wonRace = buffer.withUnsafeMutablePointerToElements { target in
            target.withMemoryRebound(to: UnsafeAtomicRawPointer.self, capacity: 1) {
                $0.pointee.compareAndSwap(from: nil, to: newPtr, success: .sequentiallyConsistent, failure: .sequentiallyConsistent)
            }
        }

        if !wonRace {
            Unmanaged<AnyObject>.fromOpaque(newPtr).release()
        }

        return wonRace
    }

    var isFilled: Bool {
        return buffer.withUnsafeMutablePointerToElements { target in
            target.withMemoryRebound(to: UnsafeAtomicRawPointer.self, capacity: 1, {
                $0.pointee.load(order: .relaxed)
            }) != nil
        }
    }

}
