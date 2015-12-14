//
//  MemoStore.swift
//  Deferred
//
//  Created by Zachary Waldowski on 12/8/15.
//  Copyright © 2014-2015 Big Nerd Ranch. Licensed under MIT.
//

import Dispatch
import AtomicSwift

// Extremely simple surface describing an async rejoin-type notifier for a
// one-off event.
protocol CallbacksList {
    init()

    var isCompleted: Bool { get }

    /// Unblock the waiter list.
    ///
    /// - precondition: `isCompleted` is false.
    /// - postcondition: `isCompleted` is true.
    func markCompleted()

    /// Become notified when the list becomes unblocked.
    ///
    /// If `isCompleted`, an implementer should immediately submit the `body`
    /// to `queue`.
    func notify(upon queue: dispatch_queue_t, body: dispatch_block_t)
}

// Reading atomically from an initialized-once, owning pointer:
//  - ObjC: "MyObject *__strong *"
//  - Swift: "UnsafeMutablePointer<MyObject?>"
private func atomicLoad<T: AnyObject>(target: UnsafeMutablePointer<T?>) -> T? {
    let ptr = __bnr_atomic_load_ptr(UnsafeMutablePointer(target))
    guard ptr != nil else { return nil }
    return Unmanaged<T>.fromOpaque(COpaquePointer(ptr)).takeUnretainedValue()
}

// Atomic compare-and-swap, but safe for an initialize-once, owning pointer:
//  - ObjC: "MyObject *__strong *"
//  - Swift: "UnsafeMutablePointer<MyObject?>"
// If the assignment is made, the new value is retained by its owning pointer.
// If the assignment is not made, the new value is not retained.
private func atomicInitialize<T: AnyObject>(target: UnsafeMutablePointer<T?>, to desired: T) -> Bool {
    let newPtr = Unmanaged.passRetained(desired).toOpaque()
    let wonRace = __bnr_atomic_compare_and_swap_ptr(UnsafeMutablePointer(target), nil, UnsafeMutablePointer(newPtr))
    if !wonRace {
        Unmanaged.passUnretained(desired).release()
    }
    return wonRace
}

// In order to assign the value of a scalar in a Deferred using atomics, we must
// box it up into something word-sized. See `atomicInitialize` above.
private final class Box<T> {
    let contents: T

    init(_ contents: T) {
        self.contents = contents
    }
}

// Heap storage that is initialized with a value once-and-only-once, atomically.
final class MemoStore<Value, OnFill: CallbacksList> {
    // Using `ManagedBufferPointer` has advantages over a custom class:
    //  - The data is efficiently stored in tail-allocated buffer space.
    //  - The buffer has a stable pointer when locked to a single element.
    //  - Better `holdsUniqueReference` support allows for future optimization.
    private typealias Manager = ManagedBufferPointer<OnFill, Box<Value>?>

    static func createWithValue(value: Value?) -> MemoStore<Value, OnFill> {
        let marker = OnFill()
        let boxed = value.map(Box.init)

        // Create storage. Swift uses a two-stage tail-allocated system
        // like ObjC's class_createInstance(2) with the extraBytes parameter.
        let ptr = Manager(bufferClass: self, minimumCapacity: 1, initialValue: { (_, _) in
            marker
        })

        // Assign the initial value to managed storage
        ptr.withUnsafeMutablePointerToElements {
            $0.initialize(boxed)
        }

        // Unblock the (empty) callbacks if needed.
        // FIXME: Should there be a way to express that this could be done
        // unsafely for performance? GCD doesn't need to.
        if value != nil {
            marker.markCompleted()
        }

        // Kindly give back an instance of the ManagedBufferPointer's buffer - self.
        return unsafeDowncast(ptr.buffer)
    }

    private init() {
        fatalError("Unavailable method cannot be called")
    }

    deinit {
        // UnsafeMutablePointer.destroy() is faster than destroy(_:) for single elements
        Manager(unsafeBufferObject: self).withUnsafeMutablePointers {
            $0.destroy()
            $1.destroy()
        }
    }

    func withValue(body: Value -> Void) {
        Manager(unsafeBufferObject: self).withUnsafeMutablePointerToElements { boxPtr in
            guard let box = atomicLoad(boxPtr) else { return }
            body(box.contents)
        }
    }

    func fill(value: Value) -> Bool {
        let box = Box(value)
        return Manager(unsafeBufferObject: self).withUnsafeMutablePointers { (onFillPtr, boxPtr) in
            guard atomicInitialize(boxPtr, to: box) else { return false }
            onFillPtr.memory.markCompleted()
            return true
        }
    }

    var onFilled: OnFill {
        return Manager(unsafeBufferObject: self).value
    }
}
