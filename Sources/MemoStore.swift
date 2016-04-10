//
//  MemoStore.swift
//  Deferred
//
//  Created by Zachary Waldowski on 12/8/15.
//  Copyright © 2014-2015 Big Nerd Ranch. Licensed under MIT.
//

import Dispatch
#if SWIFT_PACKAGE
import AtomicSwift
#endif

// Extremely simple surface describing an async rejoin-type notifier for a
// one-off event.
protocol CallbacksList {
    associatedtype FunctionBody = () -> Void

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
    func notify(executor executor: ExecutorType, body: FunctionBody)
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
final class MemoStore<Value> {
    // Using `ManagedBufferPointer` has advantages over a custom class:
    //  - The data is efficiently stored in tail-allocated buffer space.
    //  - The buffer has a stable pointer when locked to a single element.
    //  - Better `holdsUniqueReference` support allows for future optimization.
    private typealias Manager = ManagedBufferPointer<Void, Element>
    private typealias Element = Box<Value>?

    static func createWithValue(value: Value?) -> MemoStore<Value> {
        // Create storage. Swift uses a two-stage system.
        let ptr = Manager(bufferClass: self, minimumCapacity: 1) { buffer, _ in
            // Assign the initial value to managed storage
            Manager(unsafeBufferObject: buffer).withUnsafeMutablePointerToElements { boxPtr in
                boxPtr.initialize(value.map(Box.init))
            }
        }
        
        // Kindly give back an instance of the ManagedBufferPointer's buffer - self.
        return unsafeDowncast(ptr.buffer)
    }

    private init() {
        fatalError("Unavailable method cannot be called")
    }

    private func withUnsafeMutablePointer<Return>(body: UnsafeMutablePointer<Element> -> Return) -> Return {
        return Manager(unsafeBufferObject: self).withUnsafeMutablePointerToElements(body)
    }
    
    deinit {
        // UnsafeMutablePointer.destroy() is faster than destroy(_:) for single elements
        withUnsafeMutablePointer { boxPtr in
            boxPtr.destroy()
        }
    }
    
    func withValue(body: Value -> Void) {
        withUnsafeMutablePointer { boxPtr in
            guard let box = boxPtr.memory else { return }
            body(box.contents)
        }
    }
    
    func fill(value: Value) -> Bool {
        return withUnsafeMutablePointer { boxPtr in
            atomicInitialize(boxPtr, to: .init(value))
        }
    }
}
