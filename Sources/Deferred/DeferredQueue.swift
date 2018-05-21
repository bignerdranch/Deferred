//
//  DeferredQueue.swift
//  Deferred
//
//  Created by Zachary Waldowski on 2/22/18.
//  Copyright © 2018 Big Nerd Ranch. Licensed under MIT.
//

#if SWIFT_PACKAGE || COCOAPODS
import Atomics
#endif

extension Deferred {
    /// Heap storage acting as a linked list node of continuations.
    ///
    /// The use of `ManagedBuffer` ensures aligned and heap-allocated addresses
    /// for the storage. The storage is tail-allocated with a reference to the
    /// next node.
    final class Node: ManagedBuffer<AnyObject?, Continuation> {
        fileprivate static func create(with continuation: Continuation) -> Node {
            let storage = super.create(minimumCapacity: 1, makingHeaderWith: { _ in nil })

            storage.withUnsafeMutablePointers { (_, pointerToContinuation) in
                pointerToContinuation.initialize(to: continuation)
            }

            return unsafeDowncast(storage, to: Node.self)
        }

        deinit {
            _ = withUnsafeMutablePointers { (_, pointerToContinuation) in
                pointerToContinuation.deinitialize(count: 1)
            }
        }
    }

    /// A singly-linked list of continuations to be submitted after fill.
    ///
    /// A multi-producer, single-consumer atomic queue a la `DispatchGroup`:
    /// <https://github.com/apple/swift-corelibs-libdispatch/blob/master/src/semaphore.c>.
    struct Queue {
        fileprivate(set) var head: Node?
        fileprivate(set) var tail: Node?
    }
}

private extension Deferred.Node {
    /// The next node in the linked list.
    ///
    /// - warning: To alleviate data races, the next node is loaded
    ///   unconditionally. `self` must have been checked not to be the tail.
    var next: Deferred.Node {
        get {
            return withUnsafeMutablePointers { (target, _) in
                unsafeDowncast(bnr_atomic_load_and_wait(target), to: Deferred.Node.self)
            }
        }
        set {
            _ = withUnsafeMutablePointers { (target, _) in
                bnr_atomic_store(target, newValue, .relaxed)
            }
        }
    }

    func execute(with value: Value) {
        withUnsafeMutablePointers { (_, pointerToContinuation) in
            pointerToContinuation.pointee.execute(with: value)
        }
    }
}

extension Deferred {
    static func drain(from target: UnsafeMutablePointer<Queue>, continuingWith value: Value) {
        var head = bnr_atomic_store(&target.pointee.head, nil, .relaxed)
        let tail = head != nil ? bnr_atomic_store(&target.pointee.tail, nil, .release) : nil

        while let current = head {
            head = current !== tail ? current.next : nil
            current.execute(with: value)
        }
    }

    static func push(_ continuation: Continuation, to target: UnsafeMutablePointer<Queue>) -> Bool {
        let node = Node.create(with: continuation)

        if let tail = bnr_atomic_store(&target.pointee.tail, node, .release) {
            tail.next = node
            return false
        }

        _ = bnr_atomic_store(&target.pointee.head, node, .seq_cst)
        return true
    }
}
