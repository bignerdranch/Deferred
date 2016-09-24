//
//  FutureAndThen.swift
//  Deferred
//
//  Created by Zachary Waldowski on 4/2/16.
//  Copyright © 2014-2016 Big Nerd Ranch. Licensed under MIT.
//

extension FutureProtocol {
    /// Begins another asynchronous operation by passing the deferred value to
    /// `requestNextValue` once it becomes determined.
    ///
    /// `andThen` is similar to `map`, but `requestNextValue` returns another
    /// future instead of an immediate value. Use `andThen` when you want
    /// the reciever to feed into another asynchronous operation. You might hear
    /// this referred to as "chaining" or "binding".
    ///
    /// - note: It is important to keep in mind the thread safety of the
    /// `requestNextValue` closure. Creating a new asynchronous task typically
    /// involves state. Ensure the function is compatible with `executor`.
    ///
    /// - parameter executor: Context to execute the transformation on.
    /// - parameter requestNextValue: Start a new operation with the future value.
    /// - returns: The new deferred value returned by the `transform`.
    public func andThen<NewFuture: FutureProtocol>(upon executor: Executor, start requestNextValue: @escaping(Value) -> NewFuture) -> Future<NewFuture.Value> {
        let d = Deferred<NewFuture.Value>()
        upon(executor) {
            requestNextValue($0).upon(executor) {
                d.fill(with: $0)
            }
        }
        return Future(d)
    }
}
