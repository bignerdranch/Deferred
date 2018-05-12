//
//  Deferred.swift
//  Deferred
//
//  Created by John Gallagher on 7/19/14.
//  Copyright © 2014-2016 Big Nerd Ranch. Licensed under MIT.
//

import Dispatch

#if SWIFT_PACKAGE || COCOAPODS
import Atomics
#elseif XCODE
import Deferred.Atomics
#endif

/// A deferred is a value that may become determined (or "filled") at some point
/// in the future. Once a deferred value is determined, it cannot change.
public final class Deferred<Value>: FutureProtocol, PromiseProtocol {
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

    public init() {
        storage.withUnsafeMutablePointerToElements { (pointerToElement) in
            pointerToElement.initialize(to: nil)
        }

        group.enter()
    }

    /// Creates an instance resolved with `value`.
    public init(filledWith value: Value) {
        storage.withUnsafeMutablePointerToElements { (pointerToElement) in
            pointerToElement.initialize(to: Storage.box(value))
        }
    }

    deinit {
        if !isFilled {
            group.leave()
        }
    }

    // MARK: FutureProtocol

    private func notify(flags: DispatchWorkItemFlags, upon queue: DispatchQueue, execute body: @escaping(Value) -> Void) {
        group.notify(flags: flags, queue: queue) { [storage] in
            guard let ptr = storage.withAtomicPointerToElement({ bnr_atomic_ptr_load($0, .none) }) else { return }
            body(Storage.unbox(from: ptr))
        }
    }

    public func upon(_ queue: DispatchQueue, execute body: @escaping (Value) -> Void) {
        notify(flags: [ .assignCurrentContext, .inheritQoS ], upon: queue, execute: body)
    }

    public func upon(_ executor: Executor, execute body: @escaping(Value) -> Void) {
        if let queue = executor as? DispatchQueue {
            return upon(queue, execute: body)
        } else if let queue = executor.underlyingQueue {
            return upon(queue, execute: body)
        }

        notify(flags: .assignCurrentContext, upon: .any()) { (value) in
            executor.submit {
                body(value)
            }
        }
    }

    public func wait(until time: DispatchTime) -> Value? {
        guard case .success = group.wait(timeout: time),
            let ptr = storage.withAtomicPointerToElement({ bnr_atomic_ptr_load($0, .none) }) else { return nil }

        return Storage.unbox(from: ptr)
    }

    // MARK: PromiseProtocol

    public var isFilled: Bool {
        return storage.withAtomicPointerToElement {
            bnr_atomic_ptr_load($0, .none) != nil
        }
    }

    @discardableResult
    public func fill(with value: Value) -> Bool {
        let box = Storage.box(value)

        let wonRace = storage.withAtomicPointerToElement {
            bnr_atomic_ptr_compare_and_swap($0, nil, box.toOpaque(), .thread)
        }

        if wonRace {
            group.leave()
        } else {
            box.release()
        }

        return wonRace
    }
}

#if swift(>=3.1) && (os(macOS) || os(iOS) || os(tvOS) || os(watchOS))
private typealias DeferredRaw<T> = Unmanaged<AnyObject>
#else
// In order to assign the value of a scalar in a Deferred using atomics, we must
// box it up into something word-sized. See `atomicInitialize` above.
private final class Box<T> {
    let contents: T

    init(_ contents: T) {
        self.contents = contents
    }
}

private typealias DeferredRaw<T> = Unmanaged<Box<T>>
#endif

private final class DeferredStorage<Value>: ManagedBuffer<Void, DeferredRaw<Value>?> {

    typealias _Self = DeferredStorage<Value>
    typealias Element = DeferredRaw<Value>

    static func create() -> _Self {
        return unsafeDowncast(super.create(minimumCapacity: 1, makingHeaderWith: { _ in }), to: _Self.self)
    }

    func withAtomicPointerToElement<Return>(_ body: (UnsafeMutablePointer<UnsafeAtomicRawPointer>) throws -> Return) rethrows -> Return {
        return try withUnsafeMutablePointerToElements { target in
            try target.withMemoryRebound(to: UnsafeAtomicRawPointer.self, capacity: 1, body)
        }
    }

    deinit {
        guard let ptr = withAtomicPointerToElement({ bnr_atomic_ptr_load($0, .global) }) else { return }
        Element.fromOpaque(ptr).release()
    }

    static func unbox(from ptr: UnsafeMutableRawPointer) -> Value {
        let raw = Element.fromOpaque(ptr)
        #if swift(>=3.1) && (os(macOS) || os(iOS) || os(tvOS) || os(watchOS))
        // Contract of using box(_:) counterpart
        // swiftlint:disable:next force_cast
        return raw.takeUnretainedValue() as! Value
        #else
        return raw.takeUnretainedValue().contents
        #endif
    }

    static func box(_ value: Value) -> Element {
        #if swift(>=3.1) && (os(macOS) || os(iOS) || os(tvOS) || os(watchOS))
        return Unmanaged.passRetained(value as AnyObject)
        #else
        return Unmanaged.passRetained(Box(value))
        #endif
    }

}
