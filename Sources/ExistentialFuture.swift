//
//  ExistentialFuture.swift
//  Deferred
//
//  Created by Zachary Waldowski on 8/29/15.
//  Copyright © 2014-2015 Big Nerd Ranch. Licensed under MIT.
//

/*
The types in this file provide an implementation of type erasure for `FutureType`.
The techniques were derived from experimenting with `AnySequence` and `Mirror`
in a playground, the following post, and the Swift standard library:
 - https://realm.io/news/type-erased-wrappers-in-swift/
 - https://github.com/apple/swift/blob/master/stdlib/public/core/ExistentialCollection.swift.gyb
*/

// Abstract class that fake-conforms to `FutureType` for use by `Future`.
private class FutureBox<Value>: FutureType {
    func upon(executor: ExecutorType, body: Value -> Void) {
        fatalError()
    }

    func wait(time: Timeout) -> Value? {
        fatalError()
    }
}

// Concrete future wrapper given an instance of a `FutureType`.
private final class ForwardedTo<Future: FutureType>: FutureBox<Future.Value> {
    let base: Future
    init(base: Future) {
        self.base = base
    }

    override func upon(executor: ExecutorType, body: Future.Value -> Void) {
        return base.upon(executor, body: body)
    }

    override func wait(time: Timeout) -> Future.Value? {
        return base.wait(time)
    }
}

// Concrete future wrapper for an always-filled future.
private final class Always<Value>: FutureBox<Value> {
    let value: Value
    init(value: Value) {
        self.value = value
    }

    override func upon(executor: ExecutorType, body: Value -> Void) {
        executor.submit { [value] in
            body(value)
        }
    }

    override func wait(time: Timeout) -> Value? {
        return value
    }
}

// Concrete future wrapper that will never get filled.
private final class Never<Value>: FutureBox<Value> {
    override init() {}

    override func upon(executor: ExecutorType, body: Value -> Void) {}

    override func wait(time: Timeout) -> Value? {
        return nil
    }
}

/// A type-erased wrapper over any future.
///
/// Forwards operations to an arbitrary underlying future having the same
/// `Value` type, hiding the specifics of the underlying `FutureType`.
///
/// Authors can use this type to:
///
/// - Prevent clients from coupling to the specific kind of `FutureType` your
///   implementation is currently using.
/// - Publicly expose only the `FutureType` aspect of a deferred value,
///   ensuring that only your implementation can fill the deferred value
///   using the `PromiseType` aspect.
public struct Future<Value>: FutureType {
    private let box: FutureBox<Value>

    /// Create a future whose `upon(_:body:)` method forwards to `base`.
    public init<Future: FutureType where Future.Value == Value>(_ base: Future) {
        self.box = ForwardedTo(base: base)
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
    public func upon(executor: ExecutorType, body: Value -> Void) {
        return box.upon(executor, body: body)
    }

    /// Waits synchronously for the underlying future to become determined.
    ///
    /// - parameter time: A length of time to wait for the value to be determined.
    /// - returns: The determined value, if filled within the timeout, or `nil`.
    public func wait(time: Timeout) -> Value? {
        return box.wait(time)
    }
}
