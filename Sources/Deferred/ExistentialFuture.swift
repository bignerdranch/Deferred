//
//  ExistentialFuture.swift
//  Deferred
//
//  Created by Zachary Waldowski on 8/29/15.
//  Copyright © 2014-2018 Big Nerd Ranch. Licensed under MIT.
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
private class Box<Value> {
    func upon(_: Executor, execute _: @escaping(Value) -> Void) {
        fatalError()
    }

    func peek() -> Value? {
        fatalError()
    }

    func wait(until _: DispatchTime) -> Value? {
        fatalError()
    }
}

// Concrete future wrapper given an instance of a `FutureProtocol`.
private final class ForwardedTo<Future: FutureProtocol>: Box<Future.Value> {
    let base: Future
    init(base: Future) {
        self.base = base
    }

    override func upon(_ executor: Executor, execute body: @escaping(Future.Value) -> Void) {
        return base.upon(executor, execute: body)
    }

    override func peek() -> Future.Value? {
        return base.peek()
    }

    override func wait(until time: DispatchTime) -> Future.Value? {
        return base.wait(until: time)
    }
}

// Concrete future wrapper for an always-filled future.
private final class Always<Value>: Box<Value> {
    let value: Value
    init(value: Value) {
        self.value = value
    }

    override func upon(_ executor: Executor, execute body: @escaping(Value) -> Void) {
        executor.submit { [value] in
            body(value)
        }
    }

    override func peek() -> Value? {
        return value
    }

    override func wait(until _: DispatchTime) -> Value? {
        return value
    }
}

// Concrete future wrapper that will never get filled.
private final class Never<Value>: Box<Value> {
    override init() {}

    override func upon(_: Executor, execute _: @escaping(Value) -> Void) {}

    override func peek() -> Value? {
        return nil
    }

    override func wait(until _: DispatchTime) -> Value? {
        return nil
    }
}

/// A type-erased wrapper over any future.
///
/// Forwards operations to an arbitrary underlying future having the same
/// `Value` type, hiding the specifics of the underlying `FutureProtocol`.
///
/// This type may be used to:
///
/// - Prevent clients from coupling to the specific kind of `FutureProtocol` your
///   implementation is currently using.
/// - Publicly expose only the `FutureProtocol` aspect of a deferred value,
///   ensuring that only your implementation can fill the deferred value
///   using the `PromiseProtocol` aspect.
public struct Future<Value>: FutureProtocol {
    private let box: Box<Value>

    /// Create a future whose `upon(_:execute:)` methods forward to `base`.
    public init<Wrapped: FutureProtocol>(_ wrapped: Wrapped) where Wrapped.Value == Value {
        if let future = wrapped as? Future<Value> {
            self.box = future.box
        } else {
            self.box = ForwardedTo(base: wrapped)
        }
    }

    /// Wrap and forward future as if it were always filled with `value`.
    public init(value: Value) {
        self.box = Always(value: value)
    }

    private init(never: ()) {
        self.box = Never()
    }

    /// Create a future that will never get fulfilled.
    public static var never: Future<Value> {
        return Future(never: ())
    }

    /// Create a future having the same underlying future as `other`.
    public init(_ future: Future<Value>) {
        self.box = future.box
    }

    public func upon(_ executor: Executor, execute body: @escaping(Value) -> Void) {
        return box.upon(executor, execute: body)
    }

    public func peek() -> Value? {
        return box.peek()
    }

    public func wait(until time: DispatchTime) -> Value? {
        return box.wait(until: time)
    }
}

extension Future {
    @available(*, unavailable, message: "Replace with 'Future.never' for clarity.")
    public init() {
        fatalError("unavailable initializer cannot be called")
    }
}
