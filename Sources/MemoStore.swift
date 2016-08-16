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

// Atomic compare-and-swap, but safe for an initialize-once, owning pointer:
//  - ObjC: "MyObject *__strong *"
//  - Swift: "UnsafeMutablePointer<MyObject!>"
// If the assignment is made, the new value is retained by its owning pointer.
// If the assignment is not made, the new value is not retained.
private func atomicInitialize<T: AnyObject>(_ target: UnsafeMutablePointer<T?>, to desired: T) -> Bool {
    let newPtr = Unmanaged.passRetained(desired).toOpaque()
    let wonRace = target.withMemoryRebound(to: Optional<UnsafeMutableRawPointer>.self, capacity: 1) {
        OSAtomicCompareAndSwapPtr(nil, newPtr, $0)
    }
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

    static func createWithValue(_ value: Value?) -> MemoStore<Value> {
        // Create storage. Swift uses a two-stage system.
        let ptr = Manager(bufferClass: self, minimumCapacity: 1) { (buffer, _) in
            // Assign the initial value to managed storage
            Manager(unsafeBufferObject: buffer).withUnsafeMutablePointers { (_, boxPtr) in
                boxPtr.initialize(to: value.map(Box.init))
            }
        }
        
        // Kindly give back an instance of the ManagedBufferPointer's buffer - self.
        return unsafeDowncast(ptr.buffer, to: MemoStore<Value>.self)
    }

    private init() {
        fatalError("Unavailable method cannot be called")
    }

    private func withUnsafeMutablePointer<Return>(_ body: (UnsafeMutablePointer<Element>) -> Return) -> Return {
        return Manager(unsafeBufferObject: self).withUnsafeMutablePointers { body($1) }
    }
    
    deinit {
        // UnsafeMutablePointer.destroy() is faster than destroy(_:) for single elements
        _ = withUnsafeMutablePointer { boxPtr in
            boxPtr.deinitialize()
        }
    }
    
    func withValue(_ body: (Value) -> Void) {
        withUnsafeMutablePointer { boxPtr in
            guard let box = boxPtr.pointee else { return }
            body(box.contents)
        }
    }
    
    func fill(_ value: Value) -> Bool {
        return withUnsafeMutablePointer { boxPtr in
            atomicInitialize(boxPtr, to: Box(value))
        }
    }
}
