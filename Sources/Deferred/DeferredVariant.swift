//
//  DeferredVariant.swift
//  Deferred
//
//  Created by Zachary Waldowski on 2/22/18.
//  Copyright © 2018 Big Nerd Ranch. Licensed under MIT.
//

#if SWIFT_PACKAGE || COCOAPODS
import Atomics
#endif

extension Deferred {
    /// Deferred's storage. It, lock-free but thread-safe, can be initialized
    /// with a value once and only once.
    ///
    /// An underlying implementation is chosen at init. The variants that start
    /// unfilled use `ManagedBuffer` to guarantee aligned and heap-allocated
    /// addresses for atomic access, and are tail-allocated with space for the
    /// callbacks queue.
    ///
    /// - note: **Q:** Why not just stored properties? Aren't you overthinking
    ///   it? **A:** We want raw memory because Swift reserves the right to
    ///   lay out properties opaquely. To that end, the initial store done
    ///   during `init` counts as unsafe access to TSAN.
    enum Variant {
        case object(ObjectVariant)
        case native(NativeVariant)
        indirect case filled(Value)
    }

    /// Heap storage that is initialized once and only once from `nil` to a
    /// reference. See `Deferred.Variant` for more details.
    final class ObjectVariant: ManagedBuffer<Queue, AnyObject?> {
        fileprivate static func create() -> ObjectVariant {
            let storage = super.create(minimumCapacity: 1, makingHeaderWith: { _ in Queue() })

            storage.withUnsafeMutablePointers { (_, pointerToValue) in
                bnr_atomic_init(pointerToValue)
            }

            return unsafeDowncast(storage, to: ObjectVariant.self)
        }

        deinit {
            withUnsafeMutablePointers { (_, pointerToValue) in
                _ = pointerToValue.deinitialize(count: 1)
            }
        }
    }

    /// Heap storage that is initialized once and only once using a flag.
    /// See `Deferred.Variant` for more details.
    final class NativeVariant: ManagedBuffer<NativeHeader, Value> {
        fileprivate static func create() -> NativeVariant {
            let storage = super.create(minimumCapacity: 1, makingHeaderWith: { _ in NativeHeader() })
            return unsafeDowncast(storage, to: NativeVariant.self)
        }

        deinit {
            withUnsafeMutablePointers { (pointerToHeader, pointerToValue) in
                if pointerToHeader.pointee.isInitialized {
                    pointerToValue.deinitialize(count: 1)
                }
            }
        }
    }

    /// The tail-allocated header used for `NativeStorage`.
    struct NativeHeader {
        fileprivate var isInitialized = false
        fileprivate var queue = Queue()
    }
}

extension Deferred.Variant {
    init() {
        if Value.self is AnyObject.Type {
            self = .object(.create())
        } else {
            self = .native(.create())
        }
    }

    init(for value: Value) {
        self = .filled(value)
    }
}

extension Deferred.Variant {
    /// Adds the `continuation` to the queue. If filled, drain the queue to
    /// execute it immediately.
    func notify(_ continuation: Deferred.Continuation) {
        switch self {
        case .object(let storage):
            storage.withUnsafeMutablePointers { (pointerToQueue, pointerToValue) in
                guard Deferred.push(continuation, to: pointerToQueue),
                    let existingValue = unsafeBitCast(bnr_atomic_load(pointerToValue, .seq_cst), to: Value?.self) else { return }
                Deferred.drain(from: pointerToQueue, continuingWith: existingValue)
            }
        case .native(let storage):
            storage.withUnsafeMutablePointers { (pointerToHeader, pointerToValue) in
                guard Deferred.push(continuation, to: &pointerToHeader.pointee.queue),
                    bnr_atomic_load(&pointerToHeader.pointee.isInitialized, .seq_cst) else { return }
                Deferred.drain(from: &pointerToHeader.pointee.queue, continuingWith: pointerToValue.pointee)
            }
        case .filled(let value):
            continuation.execute(with: value)
        }
    }

    func load() -> Value? {
        switch self {
        case .object(let storage):
            return storage.withUnsafeMutablePointers { (_, pointerToValue) in
                unsafeBitCast(bnr_atomic_load(pointerToValue, .relaxed), to: Value?.self)
            }
        case .native(let storage):
            return storage.withUnsafeMutablePointers { (pointerToHeader, pointerToValue) in
                bnr_atomic_load(&pointerToHeader.pointee.isInitialized, .relaxed) ? pointerToValue.pointee : nil
            }
        case .filled(let value):
            return value
        }
    }

    func store(_ value: Value) -> Bool {
        switch self {
        case .object(let storage):
            return storage.withUnsafeMutablePointers { (pointerToHeader, pointerToValue) -> Bool in
                guard bnr_atomic_initialize_once(pointerToValue, unsafeBitCast(value, to: AnyObject.self)) else { return false }
                Deferred.drain(from: pointerToHeader, continuingWith: value)
                return true
            }
        case .native(let storage):
            return storage.withUnsafeMutablePointers { (pointerToHeader, pointerToValue) -> Bool in
                guard bnr_atomic_initialize_once(&pointerToHeader.pointee.isInitialized, { pointerToValue.initialize(to: value) }) else { return false }
                Deferred.drain(from: &pointerToHeader.pointee.queue, continuingWith: value)
                return true
            }
        case .filled:
            return false
        }
    }
}
