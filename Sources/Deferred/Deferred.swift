//
//  Deferred.swift
//  Deferred
//
//  Created by John Gallagher on 7/19/14.
//  Copyright © 2014-2015 Big Nerd Ranch. Licensed under MIT.
//

import Dispatch
import Atomics

/// A deferred is a value that may become determined (or "filled") at some point
/// in the future. Once a deferred value is determined, it cannot change.
public struct Deferred<Value>: FutureType, PromiseType {

    private let storage: DeferredStorage<Value>

    /// Initialize an unfilled Deferred.
    public init() {
        storage = .create(with: nil)
        storage.group.enter()
    }
    
    /// Initialize a Deferred filled with the given value.
    public init(value: Value) {
        storage = .create(with: value)
    }

    // MARK: FutureType

    /// Check whether or not the receiver is filled.
    public var isFilled: Bool {
        return storage.isFilled
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
            guard let value = storage.value else { return }
            body(value)
        }

        if let queue = executor.underlyingQueue {
            storage.group.notify(flags: [.assignCurrentContext, .inheritQoS], queue: queue, execute: callBodyWithValue)
        } else {
            let queue = type(of: self).genericQueue
            storage.group.notify(flags: .assignCurrentContext, queue: queue) {
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
        guard case .success = storage.group.wait(timeout: time.rawValue) else {
            return nil
        }

        return storage.value
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
            storage.group.leave()
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
        ManagedBufferPointer<DispatchGroup, AnyObject?>
    private typealias Storage = DeferredStorage<Value>

    static func create(with value: Value?) -> Storage {
        let pointer = BufferPointer(bufferClass: self, minimumCapacity: 1) { _ in
            return DispatchGroup()
        }

        pointer.withUnsafeMutablePointerToElements { (boxPtr) in
            boxPtr.initialize(to: value.map { $0 as AnyObject })
        }
        return unsafeDowncast(pointer.buffer, to: self)
    }

    deinit {
        if !isFilled {
            group.leave()
        }

        buffer.withUnsafeMutablePointers { (pointerToHeader, pointerToElements) -> Void in
            pointerToElements.deinitialize()
            pointerToHeader.deinitialize()
        }
    }

    private var buffer: BufferPointer {
        return BufferPointer(unsafeBufferObject: self)
    }

    private func withAtomicPointerToValue<Return>(_ body: (inout UnsafeAtomicRawPointer) throws -> Return) rethrows -> Return {
        return try buffer.withUnsafeMutablePointerToElements { target in
            try target.withMemoryRebound(to: UnsafeAtomicRawPointer.self, capacity: 1) { atomicTarget in
                try body(&atomicTarget.pointee)
            }
        }
    }

    var group: DispatchGroup {
        return buffer.header
    }

    // Atomic compare-and-swap, but safe for an initialize-once, owning pointer:
    //  - ObjC: "MyObject *__strong *"
    //  - Swift: "UnsafeMutablePointer<MyObject!>"
    // If the assignment is made, the new value is retained by its owning pointer.
    // If the assignment is not made, the new value is not retained.
    func fill(_ value: Value) -> Bool {
        let newPtr = Unmanaged.passRetained(value as AnyObject).toOpaque()

        let wonRace = withAtomicPointerToValue {
            $0.compareAndSwap(from: nil, to: newPtr, order: .acquireRelease)
        }

        if !wonRace {
            Unmanaged<AnyObject>.fromOpaque(newPtr).release()
        }

        return wonRace
    }

    var isFilled: Bool {
        return withAtomicPointerToValue {
            $0.load(order: .relaxed) != nil
        }
    }

    var value: Value? {
        guard let ptr = withAtomicPointerToValue({
            $0.load(order: .relaxed)
        }) else { return nil }

        return (Unmanaged<AnyObject>.fromOpaque(ptr).takeUnretainedValue() as! Value)
    }

}
