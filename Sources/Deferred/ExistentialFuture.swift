//
//  ExistentialFuture.swift
//  Deferred
//
//  Created by Zachary Waldowski on 8/29/15.
//  Copyright © 2014-2016 Big Nerd Ranch. Licensed under MIT.
//

import Dispatch

/*
The types in this file provide an implementation of type erasure for `FutureProtocol`.
The techniques were derived from experimenting with `AnySequence` and `Mirror`
in a playground, the following post, and the Swift standard library:
 - https://realm.io/news/type-erased-wrappers-in-swift/
 - https://github.com/apple/swift/blob/master/stdlib/public/core/ExistentialCollection.swift.gyb
*/

// Abstract class that fake-conforms to `FutureProtocol` for use by `Future`.
private class FutureBox<Value> {
    func upon(_: Executor, execute _: @escaping(Value) -> Void) {
        fatalError()
    }

    func upon(_: DispatchQueue, execute _: @escaping(Value) -> Void) {
        fatalError()
    }

    func wait(until _: DispatchTime) -> Value? {
        fatalError()
    }
}

// Concrete future wrapper given an instance of a `FutureProtocol`.
private final class ForwardedTo<Future: FutureProtocol>: FutureBox<Future.Value> {
    let base: Future
    init(base: Future) {
        self.base = base
    }

    override func upon(_ executor: DispatchQueue, execute body: @escaping(Future.Value) -> Void) {
        return base.upon(executor, execute: body)
    }

    override func upon(_ executor: Executor, execute body: @escaping(Future.Value) -> Void) {
        return base.upon(executor, execute: body)
    }

    override func wait(until time: DispatchTime) -> Future.Value? {
        return base.wait(until: time)
    }
}

// Concrete future wrapper for an always-filled future.
private final class Always<Value>: FutureBox<Value> {
    let value: Value
    init(value: Value) {
        self.value = value
    }

    override func upon(_ queue: DispatchQueue, execute body: @escaping(Value) -> Void) {
        queue.async { [value] in
            body(value)
        }
    }

    override func upon(_ executor: Executor, execute body: @escaping(Value) -> Void) {
        executor.submit { [value] in
            body(value)
        }
    }

    override func wait(until _: DispatchTime) -> Value? {
        return value
    }
}

// Concrete future wrapper that will never get filled.
private final class Never<Value>: FutureBox<Value> {
    override init() {}

    override func upon(_: DispatchQueue, execute _: @escaping(Value) -> Void) {}

    override func upon(_: Executor, execute _: @escaping(Value) -> Void) {}

    override func wait(until _: DispatchTime) -> Value? {
        return nil
    }
}

/// A type-erased wrapper over any future.
///
/// Forwards operations to an arbitrary underlying future having the same
/// `Value` type, hiding the specifics of the underlying `FutureProtocol`.
///
/// Authors can use this type to:
///
/// - Prevent clients from coupling to the specific kind of `FutureProtocol` your
///   implementation is currently using.
/// - Publicly expose only the `FutureProtocol` aspect of a deferred value,
///   ensuring that only your implementation can fill the deferred value
///   using the `PromiseProtocol` aspect.
public struct Future<Value>: FutureProtocol {
    private let box: FutureBox<Value>

    /// Create a future whose `upon(_:execute:)` methods forward to `base`.
    public init<OtherFuture: FutureProtocol>(_ base: OtherFuture)
        where OtherFuture.Value == Value {
        if let future = base as? Future<Value> {
            self.box = future.box
        } else {
            self.box = ForwardedTo(base: base)
        }
    }

    /// Wrap and forward future as if it were always filled with `value`.
    public init(value: Value) {
        self.box = Always(value: value)
    }

    /// Create a future that will never get fulfilled.
    public init() {
        self.box = Never()
    }

    /// Create a future having the same underlying future as `other`.
    public init(_ other: Future<Value>) {
        self.box = other.box
    }

    /// Call some `body` closure once the underlying future's value is
    /// determined.
    ///
    /// If the value is determined, the closure will be submitted to the
    /// `executor` immediately.
    public func upon(_ queue: DispatchQueue, execute body: @escaping(Value) -> Void) {
        return box.upon(queue, execute: body)
    }

    /// Call some `body` closure once the underlying future's value is
    /// determined.
    ///
    /// If the value is determined, the closure will be submitted to the
    /// `executor` immediately.
    public func upon(_ executor: Executor, execute body: @escaping(Value) -> Void) {
        return box.upon(executor, execute: body)
    }

    /// Waits synchronously for the underlying future to become determined.
    ///
    /// - parameter time: A length of time to wait for the value to be determined.
    /// - returns: The determined value, if filled within the timeout, or `nil`.
    public func wait(until time: DispatchTime) -> Value? {
        return box.wait(until: time)
    }
}
