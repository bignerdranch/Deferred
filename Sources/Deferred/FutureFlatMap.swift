//
//  FutureFlatMap.swift
//  Deferred
//
//  Created by Zachary Waldowski on 4/2/16.
//  Copyright © 2014-2016 Big Nerd Ranch. Licensed under MIT.
//

extension FutureType {
    /// Begins another asynchronous operation by passing the deferred value to
    /// `requestNextValue` once it becomes determined.
    ///
    /// `flatMap` is similar to `map`, but `transform` returns another
    /// `FutureType` instead of an immediate value. Use `flatMap` when you want
    /// this future to feed into another asynchronous operation. You might hear
    /// this referred to as "chaining" or "binding"; it is the operation of
    /// "flattening" a future that would otherwise contain another future.
    ///
    /// - note: It is important to keep in mind the thread safety of the
    /// `requestNextValue` closure. Creating a new asynchronous task typically
    /// involves stored state. Ensure the `body` is designed for use with the
    /// `executor`.
    ///
    /// - parameter executor: Context to execute the transformation on.
    /// - parameter requestNextValue: Start a new operation with the future value.
    /// - returns: The new deferred value returned by the `transform`.
    public func flatMap<NewFuture: FutureType>(upon executor: ExecutorType, _ requestNextValue: @escaping(Value) -> NewFuture) -> Future<NewFuture.Value> {
        let d = Deferred<NewFuture.Value>()
        upon(executor) {
            requestNextValue($0).upon(executor) {
                d.fill($0)
            }
        }
        return Future(d)
    }
}
