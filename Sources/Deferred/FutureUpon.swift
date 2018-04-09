//
//  FutureUpon.swift
//  Deferred
//
//  Created by Zachary Waldowski on 4/2/16.
//  Copyright © 2014-2018 Big Nerd Ranch. Licensed under MIT.
//

import Dispatch

extension FutureProtocol {
    /// The natural executor for use with futures; a policy of the framework to
    /// allow for shorthand syntax with `Future.upon(_:execute:)` and others.
    public typealias PreferredExecutor = DispatchQueue

    /// The executor to use as a default argument to `upon` methods on `Future`.
    ///
    /// Don't provide a default parameter using this declaration unless doing
    /// so is unambiguous. For instance, `map` and `andThen` once had a default
    /// executor, but users found it unclear wherethe  handlers executed.
    public static var defaultUponExecutor: PreferredExecutor {
        return DispatchQueue.any()
    }

    /// Call some `body` closure in the background once the value is determined.
    ///
    /// If the value is determined, the closure will be enqueued immediately,
    /// but this call is always asynchronous.
    public func upon(_ executor: PreferredExecutor = Self.defaultUponExecutor, execute body: @escaping(Value) -> Void) {
        upon(executor as Executor, execute: body)
    }
}
