//
//  Deferred.swift
//  Deferred
//
//  Created by John Gallagher on 7/19/14.
//  Copyright © 2014-2016 Big Nerd Ranch. Licensed under MIT.
//

import Dispatch
import Atomics

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

    private func notify(flags: DispatchWorkItemFlags, upon queue: DispatchQueue, execute body: @escaping(@escaping() -> Value) -> ()) {
        group.notify(flags: flags, queue: queue) { [storage] in
            guard let ptr = storage.withAtomicPointerToElement({ $0.load(order: .relaxed) }) else { return }

            body {
                Storage.unbox(from: ptr)
            }
        }
    }

    public func upon(_ queue: DispatchQueue, execute body: @escaping (Value) -> Void) {
        notify(flags: [ .assignCurrentContext, .inheritQoS ], upon: queue) { (getValue) in
            body(getValue())
        }
    }

    public func upon(_ executor: Executor, execute body: @escaping(Value) -> Void) {
        if let queue = executor.underlyingQueue {
            return upon(queue, execute: body)
        } else if let queue = executor as? DispatchQueue {
            return upon(queue, execute: body)
        }

        notify(flags: .assignCurrentContext, upon: .any()) { (getValue) in
            executor.submit {
                body(getValue())
            }
        }
    }

    public func wait(until time: DispatchTime) -> Value? {
        guard case .success = group.wait(timeout: time),
            let ptr = storage.withAtomicPointerToElement({ $0.load(order: .relaxed) }) else { return nil }

        return Storage.unbox(from: ptr)
    }

    // MARK: PromiseProtocol

    public var isFilled: Bool {
        return storage.withAtomicPointerToElement {
            $0.load(order: .relaxed) != nil
        }
    }

    @discardableResult
    public func fill(with value: Value) -> Bool {
        let box = Storage.box(value)
        let boxPtr = Unmanaged.passRetained(box).toOpaque()

        let wonRace = storage.withAtomicPointerToElement {
            $0.compareAndSwap(from: nil, to: boxPtr, order: .acquireRelease)
        }

        if wonRace {
            group.leave()
        } else {
            Unmanaged<AnyObject>.fromOpaque(boxPtr).release()
        }

        return wonRace
    }
}

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
    private final class DeferredStorage<Value>: ManagedBuffer<Void, AnyObject?> {
        deinit {
            _ = withUnsafeMutablePointerToElements { (pointerToElements) in
                pointerToElements.deinitialize()
            }
        }

        static func unbox(from ptr: UnsafeMutableRawPointer) -> Value {
            // This conversion is guaranteed by convention through id-as-Any.
            // swiftlint:disable:next force_cast
            return Unmanaged<AnyObject>.fromOpaque(ptr).takeUnretainedValue() as! Value
        }

        static func box(_ value: Value) -> AnyObject {
            return value as AnyObject
        }
    }
#else
    // In order to assign the value of a scalar in a Deferred using atomics, we must
    // box it up into something word-sized. See `atomicInitialize` above.
    private final class Box<T> {
        let contents: T

        init(_ contents: T) {
            self.contents = contents
        }
    }

    private final class DeferredStorage<Value>: ManagedBuffer<Void, Box<Value>?> {
        deinit {
            _ = withUnsafeMutablePointerToElements { (pointerToElements) in
                pointerToElements.deinitialize()
            }
        }

        static func unbox(from ptr: UnsafeMutableRawPointer) -> Value {
            return Unmanaged<Box<Value>>.fromOpaque(ptr).takeUnretainedValue().contents
        }

        static func box(_ value: Value) -> Box<Value> {
            return Box(value)
        }
    }
#endif

extension DeferredStorage {
    typealias _Self = DeferredStorage<Value>

    static func create() -> _Self {
        return unsafeDowncast(super.create(minimumCapacity: 1, makingHeaderWith: { _ in }), to: _Self.self)
    }

    func withAtomicPointerToElement<Return>(_ body: (inout UnsafeAtomicRawPointer) throws -> Return) rethrows -> Return {
        return try withUnsafeMutablePointerToElements { target in
            try target.withMemoryRebound(to: UnsafeAtomicRawPointer.self, capacity: 1) { (atomicPointertoElement) in
                try body(&atomicPointertoElement.pointee)
            }
        }
    }
}
