//
//  Executor.swift
//  Deferred
//
//  Created by Zachary Waldowski on 3/29/16.
//  Copyright © 2014-2018 Big Nerd Ranch. Licensed under MIT.
//

import Dispatch
import Foundation
#if !os(macOS) && !os(iOS) && !os(tvOS) && !os(watchOS)
    import CoreFoundation
#endif

/// An executor calls closures submitted to it, typically in first-in, first-out
/// order on some other thread. An executor may also model locks or atomicity.
///
/// Throughout the Deferred module, `upon` methods (or parameters to methods
/// built around `upon`, such as `map`) are overloaded to take an `Executor`
/// as well as the standard `DispatchQueue`.
///
/// A custom executor is a customization point into the asynchronous semantics
/// of a future, and may be important for ensuring the thread safety of an
/// `upon` closure.
///
/// For instance, the concurrency model of Apple's Core Data framework requires
/// that objects be accessed from other threads using the `perform(_:)`
/// method, and not just thread isolation. Here, we connect that to Deferred:
///
///     extension NSManagedObjectContext: Executor {
///
///          func submit(body: @escaping() -> Void) {
///              perform(body)
///          }
///
///     }
///
/// And use it like you would a dispatch queue, with `upon`:
///
///     let context: NSManagedObjectContext = ...
///     let personJSON: Future<JSON> = ...
///     let person: Future<Person> = personJSON.map(upon: context) { json in
///         Person(json: json, inContext: context)
///     }
///
public protocol Executor: class {
    /// Execute the `body` closure.
    func submit(_ body: @escaping() -> Void)

    /// Execute the `workItem`.
    func submit(_ workItem: DispatchWorkItem)
}

extension Executor {
    /// By default, submits the closure contents of the work item.
    public func submit(_ workItem: DispatchWorkItem) {
        submit(workItem.perform)
    }
}

/// Dispatch queues invoke function bodies submitted to them serially in FIFO
/// order. A queue will only invoke one-at-a-time, but independent queues may
/// each invoke concurrently with respect to each other.
extension DispatchQueue: Executor {
    /// A generic catch-all dispatch queue, for when you just want to throw some
    /// work onto the concurrent pile. As an alternative to the `.utility` QoS
    /// global queue, work dispatched onto this queue on platforms with support
    /// for QoS will match the QoS of the caller.
    public static func any() -> DispatchQueue {
        // The technique is described and used in Core Foundation:
        // http://opensource.apple.com/source/CF/CF-1153.18/CFInternal.h
        // https://github.com/apple/swift-corelibs-foundation/blob/master/CoreFoundation/Base.subproj/CFInternal.h#L869-L889
        let qosClass: DispatchQoS.QoSClass
        #if os(iOS) || os(macOS) || os(tvOS) || os(watchOS)
            qosClass = DispatchQoS.QoSClass(rawValue: qos_class_self()) ?? .utility
        #else
            qosClass = .utility
        #endif
        return .global(qos: qosClass)
    }

    public func submit(_ body: @escaping() -> Void) {
        async(execute: body)
    }

    public func submit(_ workItem: DispatchWorkItem) {
        async(execute: workItem)
    }
}

/// An operation queue manages a number of operation objects, making high
/// level features like cancellation and dependencies simple.
///
/// As an `Executor`, `upon` closures are enqueued as non-cancellable
/// operations. This is ideal for regulating the call relative to other
/// operations in the queue.
extension OperationQueue: Executor {
    public func submit(_ body: @escaping() -> Void) {
        addOperation(body)
    }
}

/// A run loop processes events on a thread, and is a fundamental construct in
/// Cocoa applications.
///
/// As an `Executor`, submitted functions are invoked on the next iteration
/// of the run loop.
extension CFRunLoop: Executor {
    public func submit(_ body: @escaping() -> Void) {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
            CFRunLoopPerformBlock(self, CFRunLoopMode.defaultMode.rawValue, body)
        #else
            CFRunLoopPerformBlock(self, kCFRunLoopDefaultMode, body)
        #endif
        CFRunLoopWakeUp(self)
    }
}

/// A run loop processes events on a thread, and is a fundamental construct in
/// Cocoa applications.
///
/// As an `Executor`, submitted functions are invoked on the next iteration
/// of the run loop.
extension RunLoop: Executor {
    public func submit(_ body: @escaping() -> Void) {
        if #available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
            perform(body)
        } else {
            getCFRunLoop().submit(body)
        }
    }
}
