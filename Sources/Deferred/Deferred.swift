//
//  Deferred.swift
//  Deferred
//
//  Created by John Gallagher on 7/19/14.
//  Copyright © 2014-2018 Big Nerd Ranch. Licensed under MIT.
//

import Dispatch

/// A deferred is a value that may become determined (or "filled") at some point
/// in the future. Once a deferred value is determined, it cannot change.
public final class Deferred<Value>: FutureProtocol, PromiseProtocol {
    /// The primary storage, initialized with a value once-and-only-once (at
    /// init or later).
    private let variant: Variant
    // A semaphore that keeps efficiently keeps track of a callbacks list.
    private let group = DispatchGroup()

    public init() {
        variant = Variant()
        group.enter()
    }

    /// Creates an instance resolved with `value`.
    public init(filledWith value: Value) {
        variant = Variant(for: value)
    }

    deinit {
        if !isFilled {
            group.leave()
        }
    }

    // MARK: FutureProtocol

    private func notify(flags: DispatchWorkItemFlags, upon queue: DispatchQueue, execute body: @escaping(Value) -> Void) {
        group.notify(flags: flags, queue: queue) { [variant] in
            guard let value = variant.load() else { return }
            body(value)
        }
    }

    public func upon(_ queue: DispatchQueue, execute body: @escaping (Value) -> Void) {
        notify(flags: [ .assignCurrentContext, .inheritQoS ], upon: queue, execute: body)
    }

    public func upon(_ executor: Executor, execute body: @escaping(Value) -> Void) {
        if let queue = executor as? DispatchQueue {
            return upon(queue, execute: body)
        } else if let queue = executor.underlyingQueue {
            return upon(queue, execute: body)
        }

        notify(flags: .assignCurrentContext, upon: .any()) { (value) in
            executor.submit {
                body(value)
            }
        }
    }

    public func peek() -> Value? {
        return variant.load()
    }

    public func wait(until time: DispatchTime) -> Value? {
        guard case .success = group.wait(timeout: time) else { return nil }
        return peek()
    }

    // MARK: PromiseProtocol

    @discardableResult
    public func fill(with value: Value) -> Bool {
        let wonRace = variant.store(value)

        if wonRace {
            group.leave()
        }

        return wonRace
    }
}
