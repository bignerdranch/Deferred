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
public final class Deferred<Value>: FutureType, PromiseType {

    // Using `ManagedBuffer` has advantages:
    //  - The buffer has a stable pointer when locked to a single element.
    //  - The buffer is appropriately aligned for atomic access.
    //  - Better `holdsUniqueReference` support allows for future optimization.
    private typealias Storage =
        DeferredStorage<Value>

    // Heap storage that is initialized with a value once-and-only-once.
    private let storage = Storage.create()
    // A semaphore that keeps efficiently keeps track of a callbacks list.
    private let group = DispatchGroup()

    /// Initialize an unfilled Deferred.
    public init() {
        storage.withUnsafeMutablePointerToElements { (pointerToElement) in
            pointerToElement.initialize(to: nil)
        }

        group.enter()
    }
    
    /// Initialize a Deferred filled with the given value.
    public init(value: Value) {
        storage.withUnsafeMutablePointerToElements { (pointerToElement) in
            pointerToElement.initialize(to: value as AnyObject)
        }
    }

    deinit {
        if !isFilled {
            group.leave()
        }
    }

    // MARK: -

    private func notify(flags: DispatchWorkItemFlags, upon queue: DispatchQueue, execute body: @escaping(@escaping() -> Value) -> ()) {
        group.notify(flags: flags, queue: queue) { [storage] in
            guard let ptr = storage.withAtomicPointerToElement({ $0.load(order: .relaxed) }) else { return }

            body {
                Unmanaged<AnyObject>.fromOpaque(ptr).takeUnretainedValue() as! Value
            }
        }
    }

    // MARK: FutureType

    /// Check whether or not the receiver is filled.
    public var isFilled: Bool {
        return storage.withAtomicPointerToElement {
            $0.load(order: .relaxed) != nil
        }
    }

    /// Call some `body` closure once the value is determined.
    ///
    /// If the value is determined, the function will be submitted to
    /// to the `executor` immediately.
    ///
    /// - parameter executor: A context for handling the `body` on fill.
    /// - parameter body: A function that uses the determined value.
    public func upon(_ executor: ExecutorType, body: @escaping(Value) -> Void) {
        if let queue = executor.underlyingQueue {
            notify(flags: [ .assignCurrentContext, .inheritQoS ], upon: queue) { (getValue) in
                body(getValue())
            }
        } else {
            notify(flags: .assignCurrentContext, upon: type(of: self).genericQueue) { (getValue) in
                executor.submit {
                    body(getValue())
                }
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
        guard case .success = group.wait(timeout: time.rawValue),
            let ptr = storage.withAtomicPointerToElement({ $0.load(order: .relaxed) }) else { return nil }

        return (Unmanaged<AnyObject>.fromOpaque(ptr).takeUnretainedValue() as! Value)
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
        let newPtr = Unmanaged.passRetained(value as AnyObject).toOpaque()

        let wonRace = storage.withAtomicPointerToElement {
            $0.compareAndSwap(from: nil, to: newPtr, order: .acquireRelease)
        }

        if wonRace {
            group.leave()
        } else {
            Unmanaged<AnyObject>.fromOpaque(newPtr).release()
        }

        return wonRace
    }
}

private final class DeferredStorage<Value>: ManagedBuffer<Void, AnyObject?> {

    typealias _Self = DeferredStorage<Value>

    static func create() -> _Self {
        return unsafeDowncast(super.create(minimumCapacity: 1, makingHeaderWith: { _ in }), to: _Self.self)
    }

    deinit {
        _ = withUnsafeMutablePointerToElements { (pointerToElements) in
            pointerToElements.deinitialize()
        }
    }

    func withAtomicPointerToElement<Return>(_ body: (inout UnsafeAtomicRawPointer) throws -> Return) rethrows -> Return {
        return try withUnsafeMutablePointerToElements { target in
            try target.withMemoryRebound(to: UnsafeAtomicRawPointer.self, capacity: 1) { (atomicPointertoElement) in
                try body(&atomicPointertoElement.pointee)
            }
        }
    }

}
