//
//  MemoStore.swift
//  Deferred
//
//  Created by Zachary Waldowski on 12/8/15.
//  Copyright © 2014-2015 Big Nerd Ranch. Licensed under MIT.
//

import Dispatch

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

// Atomic compare-and-swap, but safe for an initialize-once, owning pointer:
//  - ObjC: "MyObject *__strong *"
//  - Swift: "UnsafeMutablePointer<MyObject!>"
// If the assignment is made, the new value is retained by its owning pointer.
// If the assignment is not made, the new value is not retained.
private func atomicInitialize<T: AnyObject>(target: UnsafeMutablePointer<T?>, to desired: T) -> Bool {
    let newPtr = Unmanaged.passRetained(desired).toOpaque()
    let wonRace = OSAtomicCompareAndSwapPtr(nil, UnsafeMutablePointer(newPtr), UnsafeMutablePointer(target))
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
//
// Using `ManagedBuffer` has advantages over a custom class:
//  - The side-table data is efficiently stored in tail-allocated buffer space.
//  - The Element buffer has a stable pointer when locked to a single element.
//  - Better holdsUniqueReference support allows for future optimization.
final class MemoStore<Value, OnFill: CallbacksList>: ManagedBuffer<OnFill, Box<Value>?> {
    static func create() -> MemoStore<Value, OnFill> {
        return create(1, initialValue: { _ in
            OnFill()
        }) as! MemoStore<Value, OnFill>
    }
    
    deinit {
        // super's deinit automatically destroys the Value
        withUnsafeMutablePointerToElements { boxPtr in
            // UnsafeMutablePointer.destroy() is faster than destroy(_:)
            boxPtr.destroy()
        }
    }
    
    func initializeWith(value: Value?) {
        let box = value.map(Box.init)
        withUnsafeMutablePointerToElements { boxPtr in
            boxPtr.initialize(box)
        }
    }
    
    func withValue(body: Value -> Void) {
        withUnsafeMutablePointerToElements { boxPtr in
            guard let box = boxPtr.memory else { return }
            body(box.contents)
        }
    }
    
    func fill(value: Value, onFill: OnFill -> Void) -> Bool {
        let box = Box(value)
        return withUnsafeMutablePointers { (onFillPtr, boxPtr) in
            guard atomicInitialize(boxPtr, to: box) else { return false }
            onFill(onFillPtr.memory)
            return true
        }
    }
    
    // The side-table data (our callbacks list) is ManagedBuffer.value.
    var onFilled: OnFill {
        return value
    }
}
